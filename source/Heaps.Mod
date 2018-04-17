MODULE Heaps;	(** AUTHOR "pjm/Luc Bläser/U. Glavitsch (ug)"; PURPOSE "Heap management and garbage collector"; *)

(*
	This module contains lots of low-level memory manipulations, which are best
	read together with the memory management data structure documentation.

	Garbage collector using a marking stack with overflow handling,
	References:
		Jones, Lins, Garbage Collection, Section 4.2, Algorithm 4.1
		Knuth, The Art of Computer Programming, Volume 1, Section 2.3.5, Algorithm C
*)

IMPORT Runtime (* enforce import order *), SYSTEM, Trace, Machine;

CONST

	Paranoid = TRUE; (* if paranoid =true, then during mark phase the GC can accept spurious pointers but reports them
									paranoid = false expects correct metadata and correct settings of untraced variables
									moreover, it should improve GC mark speed *)

	DebugValue = LONGINT(0DEADDEADH);	(* set non-0 to clear free storage to this value *)

	Stats* = TRUE;					(* maintain statistical counters *)

	AddressSize = SIZEOF(ADDRESS);

	MaxTries = 16;				(* max number of times to try and allocate memory, before trapping *)
	Unmarked = 0;				(* mark value of free blocks *)
	BlockSize* = 8*SIZEOF(ADDRESS);			(* power of two, <= 32 for RegisterCandidates. Must be large enough to accomodate any basic block *)
	
	ArrayAlignment = 8;			(* first array element of ArrayBlock and first data element of SystemBlock must be aligned to 0 MOD ArrayAlignment *)
	BlockHeaderSize* = 2 * AddressSize;
	HeapBlockOffset* = - 2 * AddressSize;
	TypeDescOffset* = - AddressSize;

	MaxCandidates = 1024;

	ProtTypeBit* = 31;			(** flags in TypeDesc, RoundUp(log2(MaxTags)) low bits reserved for extLevel *)

	
	FlagsOfs = AddressSize * 3;			(* flags offset in TypeDesc *)
	ModOfs* = AddressSize * 4;			(* moduleAdr offset in TypeDesc *)
	TypeNameOfs = AddressSize * 5;		(* type name offset in TypeDesc *)
	ModNameOfs = AddressSize * 2;		(* module name offset in ModuleDesc *)

	MinPtrOfs = -40000000H;	(* sentinel offset for ptrOfs *)
	MethodEndMarker* = MinPtrOfs;   (* marks the end of the method addresses, used in Info.ModuleDetails *)

	NilVal* = 0;

	NumPriorities* = 6;

	HeuristicStackInspectionGC* = 0;
	MetaDataForStackGC* = 1;

	(* generations *)
	Old = 1; 
	Young = 0;
	GenerationMask = 2;
	(* card set for generational GC *)
	CardSize = 4096;
	SetSize=SIZEOF(SET) * 8;


TYPE
	RootObject* = OBJECT	(* ref. Linker0 *)
		VAR nextRoot: RootObject;	(* for linking root objects during GC *)
		PROCEDURE FindRoots*;	(** abstract *)
		BEGIN HALT(301) END FindRoots;
	END RootObject;

	ProcessLink* = OBJECT (RootObject)
		VAR next*, prev*: ProcessLink
	END ProcessLink;

	ProcessQueue* = RECORD
		head*, tail*: ProcessLink
	END;

	Finalizer* = PROCEDURE {DELEGATE} (obj: ANY);

	FinalizerNode* = POINTER TO RECORD
		objWeak* {UNTRACED}: ANY;	(* weak reference to checked object *)
		nextFin: FinalizerNode;			(* in finalization list *)
		objStrong*: ANY;				(* strong reference to object to be finalized *)
		finalizer* {UNTRACED} : Finalizer;(* finalizer, if any. Untraced for the case that a finalizer points to objWeak *)
		finalizerStrong: Finalizer; 		(* strong reference to the object that is referenced by the finalizer, if any *)
	END;

	HeapBlock* = POINTER TO HeapBlockDesc;	(* base object of all heap blocks *)
	HeapBlockU = POINTER {UNSAFE,UNTRACED} TO HeapBlockDesc;	(* base object of all heap blocks *)
	HeapBlockDesc* = RECORD
		heapBlock {FICTIVE =HeapBlockOffset}: ADDRESS; 
		typeDesc {FICTIVE =TypeDescOffset}: POINTER {UNSAFE,UNTRACED} TO StaticTypeDesc; 
		(* when this is changed --> change constant in Machine too and provide changes in FoxIntermediateBackend where noted *)
		mark: LONGINT;
		dataAdr-: ADDRESS;
		size-: SIZE;
		nextMark {UNTRACED}: HeapBlock;
	END;
	
	(* mechanism of the generational garbage collector
		
		- newly created objects belong to the young generation
		- a new link from old to young must be entered in a list (an array), when the list is (nearly) full a GC cycle must be run
		- any other link, from young to young or from rootset to young does not require action
		
		- a gc cycle dealing with the young objects traverses the root set and the set of young pointers
		- older objects are not marked or traversed
		- when sweeping only unmarked objects not older than the sweep generation can be freed
				
		- objects that survive a collection are considered old and are always moved to the tenured objects 
	
	*)

	FreeBlock* = POINTER TO FreeBlockDesc;
	FreeBlockU = POINTER {UNSAFE,UNTRACED} TO FreeBlockDesc;
	FreeBlockDesc* = RECORD (HeapBlockDesc)
		next: FreeBlock;
	END;

	SystemBlock* = POINTER TO SystemBlockDesc;
	SystemBlockDesc = RECORD  (HeapBlockDesc)
	END;

	RecordBlock* = POINTER TO RecordBlockDesc;
	RecordBlockU = POINTER {UNSAFE,UNTRACED} TO RecordBlockDesc;
	RecordBlockDesc = RECORD  (HeapBlockDesc)
	END;

	ProtRecBlock* = POINTER TO ProtRecBlockDesc;
	ProtRecBlockU = POINTER {UNSAFE,UNTRACED} TO ProtRecBlockDesc;
	ProtRecBlockDesc* = RECORD  (RecordBlockDesc)
		count*: LONGINT;
		locked*: BOOLEAN;
		awaitingLock*, awaitingCond*: ProcessQueue;
		lockedBy*: ANY;
		waitingPriorities*: ARRAY NumPriorities OF LONGINT;
		lock*: ANY; (* generic implementation slot -- used by LinuxAos *)
	END;

	ArrayBlock* = POINTER TO ArrayBlockDesc;
	ArrayBlockU = POINTER {UNSAFE,UNTRACED} TO ArrayBlockDesc;
	ArrayBlockDesc = RECORD  (HeapBlockDesc)
	END;

	TypeInfo*= POINTER{UNSAFE,UNTRACED} TO TypeInfoDesc;
	TypeInfoDesc = RECORD
		descSize: SIZE;
		sentinel: ADDRESS;	(* = MPO-4 *)
		tag: ADDRESS; (* pointer to static type descriptor, only used by linker and loader *)
		flags: SET;
		mod: ADDRESS; (* module *)
		name*: ARRAY 32 OF CHAR;
	END;

	StaticTypeBlock*= POINTER TO StaticTypeDesc;
	StaticTypeBlockU= POINTER {UNSAFE,UNTRACED} TO StaticTypeDesc;
	StaticTypeDesc = RECORD
		info {FICTIVE =TypeDescOffset}: TypeInfo;
		recSize: SIZE;
		pointerOffsets* {UNTRACED}: PointerOffsets;
	END;

	PointerOffsets = POINTER TO ARRAY OF SIZE;
	
	Block*= POINTER	{UNSAFE,UNTRACED} TO RECORD
		heapBlock {FICTIVE =HeapBlockOffset}: HeapBlock; 
		typeBlock {FICTIVE =TypeDescOffset}: StaticTypeBlock;
	END;

	DataBlockU = POINTER {UNSAFE,UNTRACED} TO DataBlockDesc;
	DataBlockDesc*= RECORD
		heapBlock {FICTIVE =HeapBlockOffset}: POINTER {UNSAFE,UNTRACED} TO HeapBlockDesc; 
		typeDesc {FICTIVE =TypeDescOffset}: POINTER {UNSAFE,UNTRACED} TO StaticTypeDesc;
	END;
	
	ArrayDataBlockU = POINTER {UNSAFE,UNTRACED} TO ArrayDataBlockDesc;
	ArrayDataBlockDesc*= RECORD (DataBlockDesc)
		numElems: SIZE;
		current: ADDRESS; (* unused *)
		first: ADDRESS;
	END;
	
	(*StackBlock = POINTER{UNSAFE} TO StackBlockDesc;
	StackBlockDesc= RECORD
		link: StackBlock;
		pc: ADDRESS;
	END;
	*)
	
	(* a single pointer -- required as base type TD for array of pointer
		Don't rename this. Compiler refers to this TD by name
	*)
	AnyPtr = RECORD a: ANY END; 

TYPE
	GCStatus* = OBJECT
		(* the following procedures are overridden in Objects.GCStatusExt. The reason is that shared objects can only be implemented in modules Objects or higher *)

		PROCEDURE SetgcOngoing*(value: BOOLEAN);
		BEGIN
			HALT(2000);
		END SetgcOngoing;

		PROCEDURE  GetgcOngoing*(): BOOLEAN;
		BEGIN
			HALT(2001); RETURN FALSE
		END GetgcOngoing;

		PROCEDURE WaitForGCEnd*;
		BEGIN
			HALT(2002)
		END WaitForGCEnd;

	END GCStatus;

CONST
	MaxFreeLists = 20;
	FreeListBarrier = 7;
TYPE
	FreeList= RECORD minSize: SIZE; first {UNTRACED}, last{UNTRACED}: FreeBlock END;
	FreeLists = ARRAY MaxFreeLists+1 OF FreeList;
	
	MarkList = RECORD first{UNTRACED}, last{UNTRACED}: HeapBlock END;
VAR
	markList: MarkList;
	freeLists: FreeLists;
	GC*: PROCEDURE;	(** activate the garbage collector *)
	initBlock {UNTRACED}: ANY;	(* anchor for init calls *)
	currentMarkValue: LONGINT; (* all objects that have this value in their mark field are still used - initial value filled in by linker *)
	generationMarkValues : ARRAY 2 OF LONGINT; (* mark values of the generations *)
	currentGeneration: LONGINT; (* current global generation state *)
	sweepMarkValue: LONGINT; (* most recent mark value *)
	sweepBlockAdr: ADDRESS;	(* where to resume sweeping *)
	sweepMemBlock {UNTRACED}: Machine.MemoryBlock; (* where to resume sweeping *)
	candidates: ARRAY MaxCandidates OF ADDRESS; (* procedure stack pointer candidates *)
	numCandidates: LONGINT;
	rootList {UNTRACED}: RootObject;	(* list of root objects during GC - tracing does not harm but is unnecessary *)
	realtimeList {UNTRACED}: HeapBlock; (* list of realtime objects - tracing does not harm but is unnecessary *)
	newSum: SIZE;
	checkRoot: FinalizerNode;	(* list of checked objects (contains weak references to the checked objects) *)
	finalizeRoot: FinalizerNode;	(* objects scheduled for finalization (contains references to scheduled objects) *)

	freeBlockTag, systemBlockTag, recordBlockTag, protRecBlockTag, arrayBlockTag: ADDRESS;  (* same values of type ADDRESS *)

	(** Statistics. Will only be maintained if Stats = TRUE *)

	(** Memory allocation statistics *)
	Nnew- : LONGINT;			(** Number of times NewBlock has been called since system startup *)
	NnewBytes- : HUGEINT;		(** Number of bytes allocated by NewBlock since system startup *)

	(** Garbage collection statistics *)
	Ngc- : LONGINT; 			(** Number of GC cycles since system startup *)

	(** Statistics considering the last GC cyle *)
	Nmark-, Nmarked-, NfinalizeAlive-, NfinalizeDead-: LONGINT;
	NgcCyclesMark-, NgcCyclesLastRun-, NgcCyclesMax-, NgcCyclesAllRuns- : HUGEINT;
	NgcSweeps-, NgcSweepTime-, NgcSweepMax-: HUGEINT;

	gcStatus*: GCStatus;

	GCType*: LONGINT;
	freeBlockFound-, freeBlockNotFound-: LONGINT;
	EnableFreeLists, EnableReturnBlocks, trace-: BOOLEAN;

	allocationLogger-: PROCEDURE(p: ANY);

(* for low level debugging of allocation -- beware: errors or traps in allocation logger can produce catastrophy - loggers may not allocate memory  *)
PROCEDURE SetAllocationLogger*(a: PROCEDURE (p:ANY));
BEGIN
	allocationLogger := a
END SetAllocationLogger;

(* check validity of p *)
PROCEDURE CheckPointer(p: ADDRESS): BOOLEAN;
VAR 
	tdAdr: ADDRESS;
	block: Block; 
BEGIN
	block := p;
	IF (block # NIL) & Machine.ValidHeapAddress(ADDRESS OF block.heapBlock)THEN
		block := block.heapBlock;
		IF (block = NIL) THEN RETURN TRUE (* block without heap header -- considered untraced *)
		ELSIF Machine.ValidHeapAddress(ADDRESS OF block.typeBlock) THEN
			tdAdr := block.typeBlock;
			IF (tdAdr = systemBlockTag) OR (tdAdr = recordBlockTag) OR (tdAdr = protRecBlockTag) OR (tdAdr = arrayBlockTag) THEN
				RETURN TRUE;
			ELSE 
				Trace.Memory(p-64, 128);
				HALT(103);
			END
		ELSE HALT(102);
		END
	ELSE HALT(101);
	END;
	Trace.String("Heaps: invalid pointer encountered: "); Trace.Address(p); Trace.String(","); Trace.Address(block); Trace.Ln;
	HALT(100);
	RETURN FALSE
END CheckPointer;


PROCEDURE AppendToMarkList(heapBlock: HeapBlock);
BEGIN
	IF markList.first = NIL THEN
		markList.first := heapBlock
	ELSE
		markList.last.nextMark := heapBlock
	END;
	markList.last := heapBlock;
	heapBlock.nextMark := NIL; (* sanity of the list *)
END AppendToMarkList;

PROCEDURE ExtractFromMarkList(): HeapBlock;
VAR heapBlock: HeapBlock;
BEGIN
		heapBlock := markList.first;
		IF heapBlock # NIL THEN
			markList.first := heapBlock.nextMark;
			(* by the construction of AppendToMarkList, it is not necessary to update the last pointer *)
		END;
		RETURN heapBlock;
END ExtractFromMarkList;

VAR 
	cardSet: ARRAY 0x100000000 DIV SetSize DIV CardSize OF SET; (* 1 k blocks *)

PROCEDURE ShowCards*;
VAR i: LONGINT; 
BEGIN
	FOR i := 0 TO LEN(cardSet)-1 DO
		IF cardSet[i] # {} THEN
			Trace.Int(i,1); Trace.Set(cardSet[i]); Trace.Ln;
		END;
	END;
END ShowCards;

PROCEDURE ClearCardSet;
VAR i: LONGINT;
BEGIN
	FOR i := 0 TO LEN(cardSet)-1 DO
		cardSet[i] := {};
	END;
END ClearCardSet;

(* lock-free entry into card-set *)
PROCEDURE EnterInCardSet(adr: ADDRESS);
VAR value: SET;
BEGIN
	adr := adr DIV CardSize;
	IF	adr MOD SetSize IN CAS(cardSet[adr DIV SetSize],{},{}) THEN 
		RETURN 
	ELSE
		LOOP
			value := CAS (cardSet[adr DIV SetSize], {},{});
			IF CAS (cardSet[adr DIV SetSize], value, value + {adr MOD SetSize}) = value THEN EXIT END;
			(*CPU.Backoff;*)
		END;
	END;
END EnterInCardSet;

PROCEDURE CheckAssignment*(dest, src: DataBlockU);
BEGIN
	IF (src # NIL) & (src.heapBlock # NIL) & (src.heapBlock.mark MOD GenerationMask = Young) THEN
		EnterInCardSet(dest);
	END;
END CheckAssignment;

(* Sweep phase *)
PROCEDURE SweepCardSet();
VAR 
	block : HeapBlockU ;
	blockMark, blockGeneration: LONGINT;
	memBlock {UNTRACED} : Machine.MemoryBlock;
	blockAdr,a1,a2: ADDRESS;
	count,count2,count3: LONGINT;
	orgBlock: HeapBlockU;
	mark: BOOLEAN;
	time1, time2: HUGEINT;
BEGIN {UNCHECKED}
	(* blocks in the bootheap are not found by the sweep card set! *)
	time1 := Machine.GetTimer ();
	count := 0; count2 := 0;
	memBlock := Machine.memBlockHead;
	WHILE  (memBlock # NIL) DO
		blockAdr := memBlock.beginBlockAdr;
		WHILE  (blockAdr < memBlock.endBlockAdr) DO
			block := blockAdr + BlockHeaderSize;
			a1 := blockAdr DIV CardSize;
			a2 := (blockAdr + block.size) DIV CardSize;
			mark := FALSE;
			REPEAT
				mark := a1 MOD SetSize IN cardSet[a1 DIV SetSize];
				INC(a1);
			UNTIL mark OR (a1 > a2);
		
			IF mark THEN 
				IF (block.mark MOD GenerationMask = Old) & (block.mark >= generationMarkValues[Old]) THEN
					orgBlock := block.dataAdr;
					ASSERT(orgBlock # NIL);
					Inspect(orgBlock, Old);
					INC(count);
				ELSE INC(count2);
				END;
			ELSE
				INC(count3);
			END;
			blockAdr := blockAdr + block.size
		END;
		memBlock := memBlock.next;
	END;
	time2 := Machine.GetTimer ();
	(*
	TRACE(LONGINT((time2-time1) DIV (1024*1024)));
	TRACE(count,count2,count3);
	*)
END SweepCardSet;


PROCEDURE Inspect(block {UNTRACED}: ANY; generation: LONGINT);
VAR 
	heapBlock {UNTRACED}: HeapBlock; 
	rootObj{UNTRACED}: RootObject; 
	blockMeta : Block;
BEGIN
	(* ug: check for validity of block is necessary since users may assign values to pointer variables that are not real heap blocks, e.g. by using SYSTEM.VAL or ADDRESSOF *)
	IF (block = NIL) OR Paranoid & ~CheckPointer(block) THEN RETURN END;
	blockMeta := block;
	heapBlock := blockMeta.heapBlock; 
	IF (heapBlock = NIL) OR (heapBlock.mark >= currentMarkValue) OR (heapBlock.mark MOD GenerationMask > generation) & ~((blockMeta.typeBlock#NIL) & (block IS RootObject)) THEN RETURN END;
	(* blocks in the bootheap are not found by the sweep card set, thus the root objects must be traversed in all cases *)
	heapBlock.mark := currentMarkValue + Old (* surviving objects age *); 
	IF Stats THEN INC(Nmarked) END;
	IF (heapBlock IS RecordBlock) OR (heapBlock IS ProtRecBlock) OR (heapBlock IS ArrayBlock) THEN
		IF block IS RootObject THEN
			rootObj := block(RootObject);
			rootObj.nextRoot := rootList; rootList := rootObj;	(* link root list *)
		END;
		IF (LEN(blockMeta.typeBlock.pointerOffsets) > 0) OR (heapBlock IS ProtRecBlock) THEN (* not atomic or heapBlock is ProtRecBlock containing awaiting queues *)
			AppendToMarkList(heapBlock);
		END
	END
END Inspect;

(** Mark - Mark an object and its decendents. Used by findRoots. *)
PROCEDURE Mark*(p {UNTRACED}: ANY);
VAR orgBlock: ADDRESS; staticTypeBlock {UNTRACED}: StaticTypeBlock;
	orgHeapBlock {UNTRACED}: HeapBlock;
	currentArrayElemAdr, lastArrayElemAdr: ADDRESS; i: LONGINT;
	protected: ProtRecBlock;
	b {UNTRACED}: POINTER {UNSAFE} TO RECORD p: ANY END;
	meta {UNTRACED }: POINTER {UNSAFE} TO RECORD staticTypeBlock {FICTIVE=TypeDescOffset}: StaticTypeBlock; last, current, first: ADDRESS END;
BEGIN{UNCHECKED} (* omit any range checks etc.*)
	IF Stats THEN INC(Nmark) END;
	Inspect(p,currentGeneration);
	orgHeapBlock := ExtractFromMarkList();
	WHILE orgHeapBlock # NIL DO
		orgBlock := orgHeapBlock.dataAdr;
		meta := orgBlock;
		staticTypeBlock := meta.staticTypeBlock;

		IF ~(orgHeapBlock IS ArrayBlock) THEN
			FOR i := 0 TO LEN(staticTypeBlock.pointerOffsets) - 1 DO
				b := orgBlock + staticTypeBlock.pointerOffsets[i];
				Inspect(b.p,currentGeneration)
			END
		ELSE
			currentArrayElemAdr := meta.first;
			
			lastArrayElemAdr := meta.first + meta.last * staticTypeBlock.recSize;
			WHILE currentArrayElemAdr < lastArrayElemAdr DO
				FOR i := 0 TO LEN(staticTypeBlock.pointerOffsets) - 1 DO
					b := currentArrayElemAdr + staticTypeBlock.pointerOffsets[i];
					Inspect(b.p,currentGeneration)
				END;
				INC(currentArrayElemAdr, staticTypeBlock.recSize);
			END
		END;
		IF orgHeapBlock IS ProtRecBlock THEN
			protected := orgHeapBlock(ProtRecBlock);
			Inspect(protected.awaitingLock.head, currentGeneration);
			Inspect(protected.awaitingCond.head, currentGeneration);
			Inspect(protected.lockedBy, currentGeneration);
			Inspect(protected.lock, currentGeneration);
		END;
		orgHeapBlock := ExtractFromMarkList();
	END;
END Mark;

PROCEDURE MarkRealtimeObjects;
VAR heapBlock {UNTRACED}: HeapBlock;
BEGIN
	(*! disable realtime block handling for the time being
		first, we have to check that objects cannot move between mark list and realtime list
		
	heapBlock := realtimeList;
	WHILE heapBlock # NIL DO
		Mark(SYSTEM.VAL(ANY, heapBlock.dataAdr));
		heapBlock := heapBlock.nextRealtime;
	END;
	*)
END MarkRealtimeObjects;

(** WriteType - Write a type name (for tracing only). *)
PROCEDURE WriteType*(t: ADDRESS);	(* t is static type descriptor *)
VAR m: ADDRESS; i: LONGINT; ch: CHAR; 
	typeDesc: StaticTypeBlockU;
BEGIN
	typeDesc := t;
	m := typeDesc.info.mod;
	IF m # NilVal THEN	(* could be a type without module, e.g. a Java class *)
		i := 0; SYSTEM.GET (m + ModNameOfs + i, ch);
		WHILE (ch >= "0") & (ch <= "z") & (i # 32) DO
			Trace.Char(ch);
			INC(i); SYSTEM.GET (m + ModNameOfs + i, ch)
		END
	ELSE
		Trace.String("NIL")
	END;
	Trace.Char(".");
	IF typeDesc.info.name = "" THEN
		Trace.String("-")
	ELSE
		Trace.String(typeDesc.info.name);
	END;
END WriteType;

(** free list handling **)
PROCEDURE ClearFreeLists;
VAR i: LONGINT;
BEGIN
	FOR i := 0 TO MaxFreeLists DO
		freeLists[i].first := NIL;
		freeLists[i].last := NIL
	END;
END ClearFreeLists;

(* insert element in fifo, first = freeList.first; last = freeList.last *)
PROCEDURE AppendFree(VAR freeList: FreeList; block: FreeBlock);
BEGIN
	ASSERT(block.size >= freeList.minSize);
	IF freeList.first = NIL THEN
		freeList.first := block; freeList.last := block
	ELSE
		freeList.last.next := block;
		freeList.last := block;
	END;
	block.next := NIL
END AppendFree;

(* get last element from fifo *)
PROCEDURE GetFree(VAR freeList: FreeList): FreeBlock;
VAR block: FreeBlock;
BEGIN
	IF freeList.first = NIL THEN block := NIL;
	ELSIF freeList.first = freeList.last THEN block := freeList.first; freeList.first := NIL; freeList.last := NIL
	ELSE block := freeList.first; freeList.first := block.next; block.next := NIL
	END;
	RETURN block
END GetFree;

(** insert sorted into queue, no handling of last queue element *)
PROCEDURE InsertSorted(VAR freeList: FreeList; block: FreeBlock);
VAR x: FreeBlock;
BEGIN
	(* keep them ordered to avoid unnecessary splits *)
	x := freeList.first;
	WHILE x # NIL DO
		ASSERT(x # block);
		x := x.next;
	END;

	x := freeList.first;

	IF (x = NIL) OR (block.size <= x.size) THEN
		block.next := x;
		freeList.first := block;
	ELSE
		WHILE (x.next # NIL) & (block.size > x.next.size) DO  x := x.next  END;
		block.next := x.next;
		x.next := block;
	END;
END InsertSorted;

PROCEDURE AppendFreeBlock(block: FreeBlock);
VAR i: LONGINT;
BEGIN
	i := MaxFreeLists;
	WHILE (i > 0) & (freeLists[i].minSize > block.size)  DO  DEC( i )  END;

	IF i < FreeListBarrier THEN
		AppendFree(freeLists[i], block);
	ELSE
		AppendFree(freeLists[i], block);
		(*
		keeping lists sorted has some positive impact on heap utilization
	    but it slows down heap allocation speed:
	    
		InsertSorted(freeLists[i], block);
		*)

	END;
END AppendFreeBlock;

PROCEDURE FindFreeBlock( size: SIZE ): FreeBlock;
VAR prev, block: FreeBlock;  i: LONGINT;
BEGIN
	i := MaxFreeLists;
	WHILE (i > 0) & (freeLists[i].minSize > size)  DO  DEC( i )  END;

	REPEAT
		IF i < FreeListBarrier THEN
			block := GetFree(freeLists[i]);
		ELSE
			block := freeLists[i].first;
			prev := NIL;
			WHILE (block # NIL) & (block.size < size) DO
				prev := block;
				block := block.next;
			END;

			IF block # NIL THEN (* blockize >= size *)
				IF prev = NIL THEN
					freeLists[i].first := block.next;
				ELSE prev.next := block.next
				END;
				IF block = freeLists[i].last THEN
					freeLists[i].last := prev
				END;
				block.next := NIL;
			END;

			(*
			prev := freeLists[i].first;
			WHILE prev # NIL DO
				ASSERT(prev # block);
				prev := prev.next;
			END;
			*)

		END;
		INC( i )
	UNTIL (block # NIL) OR (i > MaxFreeLists);
	RETURN block
END FindFreeBlock;

PROCEDURE GetFreeBlockAndSplit(size: SIZE): FreeBlock;
VAR p,remainder: FreeBlockU; adr: ADDRESS; 
BEGIN
	p := FindFreeBlock(size);
	IF (p # NIL) & (ADDRESS(p.size) > ADDRESS (size)) THEN (* block too big - divide block into two parts: block with required size and remaining free block *)
		ASSERT(ADDRESS(p.size - size) >= BlockHeaderSize + SIZEOF(FreeBlockDesc));
		adr := p;
		remainder := adr + size;
		InitFreeBlock(remainder, Unmarked, NilVal, p.size - size);

		AppendFreeBlock(remainder);
		p.size := size;
	END;
	IF p # NIL THEN INC(freeBlockFound) ELSE INC(freeBlockNotFound) END;
	RETURN p
END GetFreeBlockAndSplit;

PROCEDURE GetFreeBlock(size: SIZE; VAR p: FreeBlock);
BEGIN
	IF EnableFreeLists THEN
		IF sweepMarkValue < currentMarkValue THEN
			(*Trace.String("clear free lists and lazy sweep"); Trace.Ln;*)
			ClearFreeLists;
			LazySweep(MAX(SIZE), p)
		END;
		p := GetFreeBlockAndSplit(size)
	ELSE
		LazySweep(size, p)
	END;
	IF size # MAX(SIZE) THEN
	INC(throughput, size);
	END;
END GetFreeBlock;

(* Sweep phase *)
PROCEDURE LazySweep(size: ADDRESS; VAR p {UNTRACED}: FreeBlock);
VAR 
	lastFreeBlockAdr: ADDRESS;
	lastFreeBlockSize: ADDRESS;
	block : HeapBlockU ; freeBlock, lastFreeBlock: FreeBlockU; 
	blockMark, blockGeneration: LONGINT; blockSize: SIZE;
	time1, time2: HUGEINT;
CONST FreeBlockHeaderSize = SIZEOF(FreeBlockDesc) + BlockHeaderSize;
CONST StrongChecks = FALSE;
BEGIN{UNCHECKED}
	INC(NgcSweeps);
	time1 := Machine.GetTimer();
	ASSERT(~EnableFreeLists OR (size = MAX(SIZE)));
	lastFreeBlockAdr := NilVal;
	lastFreeBlock := NIL;
	IF (sweepMemBlock = NIL) (* OR (sweepMarkValue < currentMarkValue)*) THEN (* restart lazy sweep including clearance of lists *)
		(* note that the order of the blocks does not necessarily represent the historical order of insertion
			as they are potentially provided by the underlying host system in with non-increasing address ranges
			blocks are sorted by Machine.Mod in an increased address range order
		*)
		sweepMemBlock := Machine.memBlockHead;
		sweepBlockAdr := Machine.memBlockHead.beginBlockAdr;
		sweepMarkValue := currentMarkValue;
	END;
	WHILE  (sweepMemBlock # NIL) DO
		WHILE  (sweepBlockAdr < sweepMemBlock.endBlockAdr) DO
			block := sweepBlockAdr + BlockHeaderSize;
			blockMark := block.mark; (* cache these values since they may be overwritten during concatenation *)
			blockGeneration := block.mark MOD GenerationMask;
			blockSize := block.size;
			IF (blockMark < generationMarkValues[blockGeneration]) THEN
				IF (block.typeDesc # freeBlockTag) THEN
					Machine.Fill32(sweepBlockAdr + FreeBlockHeaderSize, blockSize - FreeBlockHeaderSize, DebugValue);
				END;
				freeBlock := block;
				
				IF lastFreeBlockAdr = NilVal THEN
					lastFreeBlockAdr := sweepBlockAdr;
					lastFreeBlock := freeBlock;
					lastFreeBlockSize := blockSize;
				ELSE
					IF StrongChecks THEN ASSERT(lastFreeBlockAdr + lastFreeBlockSize = sweepBlockAdr) END;
					(* there are at least two contiguous free blocks - merge them *)
					INC(lastFreeBlockSize, blockSize);
					Machine.Fill32(sweepBlockAdr, FreeBlockHeaderSize, DebugValue); (* rest was already cleared before *)
				END
			ELSIF StrongChecks THEN 
				ASSERT(block.typeDesc = freeBlockTag);
			END;
			
			IF (lastFreeBlockAdr # NIL) & ((blockMark >= (* sweepMarkValue *) generationMarkValues[blockGeneration]) OR (lastFreeBlockSize >= size) OR (sweepBlockAdr + blockSize = sweepMemBlock.endBlockAdr) )
			THEN (* no further merging is possible *)
				IF StrongChecks THEN ASSERT(sweepBlockAdr + blockSize <= sweepMemBlock.endBlockAdr) END;
				IF lastFreeBlockSize >= size THEN (* block found - may be too big *)
					p := lastFreeBlock;
					InitFreeBlock(lastFreeBlock, Unmarked, NilVal, size); (* convert this block into a free heap block and clear its data *)
					IF lastFreeBlockSize > size THEN (* block too big - divide block into two parts: block with required size and remaining free block *)
						IF StrongChecks THEN ASSERT(lastFreeBlockSize - size >= FreeBlockHeaderSize) END;
						freeBlock := p + size;
						InitFreeBlock(freeBlock, Unmarked, NilVal, lastFreeBlockSize - size);
					END;
					sweepBlockAdr := lastFreeBlockAdr + size; (* make sure next lazy sweep continues after block p *)
					time2 := Machine.GetTimer()-time1;
					INC(NgcSweepTime, time2);
					IF time2 > NgcSweepMax THEN NgcSweepMax := time2 END;
					RETURN;
				ELSE
					InitFreeBlock(lastFreeBlock, Unmarked, NilVal, lastFreeBlockSize); (* convert this block into a free heap block and clear its data *)
					IF EnableFreeLists THEN 
						AppendFreeBlock(lastFreeBlock);
					END;
				END;
				lastFreeBlockAdr := NilVal;
				lastFreeBlock := NIL;
			END;
			sweepBlockAdr := sweepBlockAdr + blockSize
		END;
		sweepMemBlock := sweepMemBlock.next;
		IF sweepMemBlock # NIL THEN
			sweepBlockAdr := sweepMemBlock.beginBlockAdr
		ELSE
			sweepBlockAdr := NilVal
		END
	END;
	time2 := Machine.GetTimer()-time1;
	INC(NgcSweepTime, time2);
	IF time2 > NgcSweepMax THEN NgcSweepMax := time2 END;
END LazySweep;

(* -- useful for debugging --
PROCEDURE CheckHeap;
VAR memBlock {UNTRACED}: Machine.MemoryBlock; p, refBlock, currentArrayElemAdr, lastArrayElemAdr: ADDRESS;
	heapBlock {UNTRACED}: HeapBlock; staticTypeBlock {UNTRACED}: StaticTypeBlock; i: LONGINT;

	PROCEDURE CheckBlock(block: ADDRESS): BOOLEAN;
	VAR heapBlockAdr: ADDRESS;
	BEGIN
		IF block = NilVal THEN
			RETURN TRUE
		ELSE
			IF (block >= Machine.memBlockHead.beginBlockAdr) & (block < Machine.memBlockTail.endBlockAdr) THEN
				SYSTEM.GET(block + HeapBlockOffset, heapBlockAdr);
				IF (heapBlockAdr >= Machine.memBlockHead.beginBlockAdr) & (heapBlockAdr < Machine.memBlockTail.endBlockAdr) THEN
					RETURN TRUE
				ELSE
					RETURN FALSE
				END
			ELSE
				RETURN FALSE
			END
		END
	END CheckBlock;

BEGIN
	memBlock := Machine.memBlockHead;
	WHILE memBlock # NIL DO
		p := memBlock.beginBlockAdr;
		WHILE p < memBlock.endBlockAdr DO
			heapBlock := SYSTEM.VAL(HeapBlock, p + BlockHeaderSize);
			IF heapBlock IS SystemBlock THEN
			ELSIF heapBlock IS RecordBlock THEN
				IF heapBlock.dataAdr # NilVal THEN
					SYSTEM.GET(heapBlock.dataAdr + TypeDescOffset, staticTypeBlock); ASSERT(staticTypeBlock # NIL);
					FOR i := 0 TO LEN(staticTypeBlock.pointerOffsets) - 1 DO
						SYSTEM.GET(heapBlock.dataAdr + staticTypeBlock.pointerOffsets[i], refBlock);
						IF ~CheckBlock(refBlock) THEN
							Trace.String("SEVERE ERROR: RecordBlock = "); Trace.Hex(heapBlock.dataAdr, 8);
							Trace.String(" invalid reference at pointer offset = "); Trace.Hex(staticTypeBlock.pointerOffsets[i], 0); Trace.Ln
						END
					END;
					IF heapBlock IS ProtRecBlock THEN
						IF CheckBlock(heapBlock(ProtRecBlock).awaitingLock.head) &
							CheckBlock(heapBlock(ProtRecBlock).awaitingLock.tail) &
							CheckBlock(heapBlock(ProtRecBlock).awaitingCond.head) &
							CheckBlock(heapBlock(ProtRecBlock).awaitingCond.tail) &
							CheckBlock(heapBlock(ProtRecBlock).lockedBy) THEN
						ELSE
							Trace.String("SEVERE ERROR in awaiting queues of block = "); Trace.Hex(heapBlock.dataAdr, 8); Trace.Ln
						END
					END
				ELSE
					Trace.StringLn("SEVERE ERROR: heapBlock.dataAdr = NilVal for RecordBlock or ProtRecBlock")
				END;
			ELSIF heapBlock IS ArrayBlock THEN
				IF heapBlock.dataAdr # NilVal THEN
					SYSTEM.GET(heapBlock.dataAdr + TypeDescOffset, staticTypeBlock); ASSERT(staticTypeBlock # NIL);
					SYSTEM.GET(heapBlock.dataAdr + 2 * AddressSize, currentArrayElemAdr);
					SYSTEM.GET(heapBlock.dataAdr, lastArrayElemAdr);
					WHILE currentArrayElemAdr <= lastArrayElemAdr DO
						FOR i := 0 TO LEN(staticTypeBlock.pointerOffsets) - 1 DO
							SYSTEM.GET(currentArrayElemAdr + staticTypeBlock.pointerOffsets[i], refBlock);
							IF ~CheckBlock(refBlock) THEN
								Trace.String("SEVERE ERROR in ArrayBlock = "); Trace.Hex(currentArrayElemAdr, 8);
								Trace.String(" invalid reference at pointer offset = "); Trace.Hex(staticTypeBlock.pointerOffsets[i], 0); Trace.Ln
							END
						END;
					 	INC(currentArrayElemAdr, staticTypeBlock.recSize)
					 END
				ELSE
					Trace.StringLn("SEVERE ERROR: heapBlock.dataAdr = NilVal for ArrayBlock")
				END
			ELSIF heapBlock IS FreeBlock THEN
			ELSE
				Trace.StringLn("Invalid heap block type")
			END;
			p := p + heapBlock.size;
		END;
		memBlock := memBlock.next
	END
END CheckHeap;
*)

(* CheckCandidates - Check which candidates could be pointers, and mark them. (exported for debugging only) *)
PROCEDURE CheckCandidates*;
CONST MinDataOffset = BlockHeaderSize + SIZEOF(HeapBlockDesc) + BlockHeaderSize; (* minimal offset of data address with respect to block start address *)
VAR i, j, h: LONGINT; p, blockStart: ADDRESS; memBlock {UNTRACED}: Machine.MemoryBlock;
	heapBlock {UNTRACED}: HeapBlock;
BEGIN
	(* {numCandidates > 0} *)
	(* first sort them in increasing order using shellsort *)
	h := 1;  REPEAT h := h*3 + 1 UNTIL h > numCandidates;
	REPEAT
		h := h DIV 3;  i := h;
		WHILE i < numCandidates DO
			p := candidates[i];  j := i;
			WHILE (j >= h) & (candidates[j-h] > p) DO
				candidates[j] := candidates[j-h];  j := j-h;
			END;
			candidates[j] := p;  INC(i)
		END
	UNTIL h = 1;

	(* sweep phase *)
	i := 0;
	p := candidates[i];
	memBlock := Machine.memBlockHead;
	WHILE memBlock # NIL DO
		blockStart := memBlock.beginBlockAdr;
		WHILE (i < numCandidates) & (blockStart < memBlock.endBlockAdr) DO
			IF p < blockStart + MinDataOffset THEN (* candidate missed *)
				INC(i);
				IF i < numCandidates THEN
					p := candidates[i]
				END
			ELSE
				heapBlock := SYSTEM.VAL(HeapBlock, blockStart + BlockHeaderSize);
				IF (p = heapBlock.dataAdr) & ~(heapBlock IS FreeBlock) THEN (* heap block must not be a free block but any other heap block type *)
					Mark(SYSTEM.VAL(ANY, p))
				END;
				blockStart := blockStart + heapBlock.size;
			END
		END;
		memBlock := memBlock.next
	END;
	numCandidates := 0
END CheckCandidates;

(* Check validity of single pointer candidate and enter it into the list of candidates *)
PROCEDURE Candidate*(p: ADDRESS);
VAR memBlock, memBlockX {UNTRACED}: Machine.MemoryBlock; 
	tdAdr, heapBlockAdr: ADDRESS;
	tdPtr{UNTRACED}: POINTER {UNSAFE} TO RECORD typeAdr: ADDRESS END;
	hbPtr{UNTRACED}: POINTER {UNSAFE} TO RECORD heapBlock: HeapBlock END;
	heapBlock {UNTRACED}: HeapBlock;
BEGIN
	IF p MOD SIZEOF(ADDRESS) # 0 THEN RETURN END; 
	IF (p >= Machine.memBlockHead.beginBlockAdr) & (p < Machine.memBlockTail.endBlockAdr) THEN
		memBlock := Machine.memBlockHead;
		WHILE memBlock # NIL DO
			IF (p + HeapBlockOffset >= memBlock.beginBlockAdr) & (p + HeapBlockOffset < memBlock.endBlockAdr) THEN
				hbPtr := p + HeapBlockOffset; 
				heapBlock := hbPtr.heapBlock;
				heapBlockAdr := heapBlock ;
				IF heapBlockAdr MOD SIZEOF(ADDRESS) # 0 THEN RETURN END; 
				tdAdr :=heapBlockAdr + TypeDescOffset;
				(* check if tdAdr is a valid pointer in the heap *)
				memBlockX := Machine.memBlockHead;
				WHILE memBlockX # NIL DO 
					IF (tdAdr >= memBlockX.beginBlockAdr) & (tdAdr < memBlockX.endBlockAdr) THEN
						(* IF (heapBlock.mark >= currentMarkValue) THEN RETURN END;*)
						tdPtr := tdAdr;
						tdAdr := tdPtr.typeAdr;
						(* check whether tdAdr is a valid type descriptor address *)
						IF (tdAdr = systemBlockTag) OR (tdAdr = recordBlockTag) OR (tdAdr = protRecBlockTag) OR (tdAdr = arrayBlockTag) THEN
							candidates[numCandidates] := p;
							INC(numCandidates);
							IF numCandidates = LEN(candidates) THEN CheckCandidates END
						END;
						RETURN; (* found *)
					END;
					memBlockX := memBlockX.next
				END;
				RETURN; (* not found *)
			END;
			memBlock := memBlock.next
		END
	END
END Candidate;

(** RegisterCandidates - Register a block of pointer candidates *)
PROCEDURE RegisterCandidates*(adr: ADDRESS; size: SIZE);
VAR end, p: ADDRESS;
BEGIN
	ASSERT (adr MOD AddressSize = 0);
	ASSERT (size MOD AddressSize = 0);
	(* current processor must hold Heaps lock *)
	end := adr + size;
	WHILE adr # end DO
		SYSTEM.GET(adr, p);
		Candidate(p);
		INC(adr, AddressSize)
	END
END RegisterCandidates;



(* Check reachability of finalized objects. *)
PROCEDURE CheckFinalizedObjects;
VAR n, p, t: FinalizerNode; heapBlock {UNTRACED}: HeapBlock;

	PROCEDURE MarkDelegate(p: Finalizer);
	VAR pointer: ANY;
	BEGIN
		SYSTEM.GET(ADDRESSOF(p)+SIZEOF(ADDRESS),pointer);
		IF pointer # NIL THEN Mark(pointer) END;
	END MarkDelegate;

BEGIN
	n := checkRoot;
	WHILE n # NIL DO	(* move unmarked checked objects to finalize list *)
		SYSTEM.GET(SYSTEM.VAL(ADDRESS, n.objWeak) + HeapBlockOffset, heapBlock);
		IF (heapBlock.mark < generationMarkValues[heapBlock.mark MOD GenerationMask]) THEN
			IF n = checkRoot THEN checkRoot := n.nextFin ELSE p.nextFin := n.nextFin END;
			n.objStrong := n.objWeak;	(* anchor the object for finalization *)
			n.finalizerStrong := n.finalizer; (* anchor the finalizer for finalization *)
			t := n.nextFin; n.nextFin := finalizeRoot; finalizeRoot := n; n := t;
			IF Stats THEN DEC(NfinalizeAlive); INC(NfinalizeDead) END
		ELSE
			p := n; n := n.nextFin
		END
	END;
	(* now trace the weak references to keep finalized objects alive during this collection *)
	n := finalizeRoot;
	WHILE n # NIL DO
		MarkDelegate(n.finalizerStrong);
		Mark(n.objStrong); n := n.nextFin
	END;

	n := checkRoot;
	WHILE n # NIL DO (* list of objects that had been marked before entering CheckFinalizedObjects *)
		(* we still have to mark the weak finalizers, as they might have not been marked before  *)
		MarkDelegate(n.finalizer); n := n.nextFin
	END;
END CheckFinalizedObjects;

(** Return the next scheduled finalizer or NIL if none available. Called by finalizer object in Kernel. *)
PROCEDURE GetFinalizer* (): FinalizerNode;
VAR n: FinalizerNode;
BEGIN
	n := NIL;
	IF finalizeRoot # NIL THEN
		Machine.Acquire(Machine.Heaps);
		n := finalizeRoot;	(* take one finalizer *)
		IF n # NIL THEN
			finalizeRoot := n.nextFin; n.nextFin := NIL;
			IF Stats THEN DEC(NfinalizeDead) END;
		END;
		Machine.Release(Machine.Heaps);
	END;
	RETURN n
END GetFinalizer;

(** Check finalizers registered in the specified module, which is about to be freed or shut down. Remove all finalizer procedures in this module from the finalizer lists so they won't be called any more. *)
PROCEDURE CleanupModuleFinalizers*(codeAdr: ADDRESS; codeLen: SIZE; CONST name: ARRAY OF CHAR);
VAR n, p, t: FinalizerNode; codeEnd: ADDRESS; N1, N2: LONGINT;
BEGIN
	codeEnd := codeAdr + codeLen; N1 := 0; N2 := 0;
	Machine.Acquire(Machine.Heaps);
	n := checkRoot;
	WHILE n # NIL DO	(* iterate over checked list *)
		t := n; n := n.nextFin;
		IF (codeAdr <= SYSTEM.VAL (ADDRESS, t.finalizer)) & (SYSTEM.VAL (ADDRESS, t.finalizer) <= codeEnd) THEN
			IF t = checkRoot THEN checkRoot := t.nextFin ELSE p.nextFin := t.nextFin END;	(* remove from list *)
			IF Stats THEN DEC(NfinalizeAlive) END;
			INC(N1)
		ELSE
			p := t
		END
	END;
	(* also remove finalizers from list, so they won't be called *)
	n := finalizeRoot;
	WHILE n # NIL DO	(* iterate over finalized list *)
		t := n; n := n.nextFin;
		IF (codeAdr <= SYSTEM.VAL (ADDRESS, t.finalizer)) & (SYSTEM.VAL (ADDRESS, t.finalizer) <= codeEnd) THEN
			IF t = finalizeRoot THEN finalizeRoot := t.nextFin ELSE p.nextFin := t.nextFin END;	(* remove from list *)
			IF Stats THEN DEC(NfinalizeDead) END;
			INC(N2)
		ELSE
			p := t
		END
	END;
	Machine.Release(Machine.Heaps);
	IF (N1 # 0) OR (N2 # 0) THEN
		Machine.Acquire (Machine.TraceOutput);
		Trace.String(name); Trace.Char(" ");
		Trace.Int(N1, 1); Trace.String(" discarded finalizers, ");
		Trace.Int(N2, 1); Trace.StringLn (" pending finalizers");
		Machine.Release (Machine.TraceOutput);
	END
END CleanupModuleFinalizers;

(* Add a root object to the set of traversable objects. If in allocated heap then mark and traverse, if in Module Heap (Bootfile) then only traverse. *)
PROCEDURE AddRootObject*(rootObject: RootObject);
BEGIN
	IF rootObject = NIL THEN (* nothing *)
	ELSIF CheckPointer(rootObject) THEN
		(* object in heap, must be fully marked and traversed *)
		Mark(rootObject)
	ELSE
		(* object in bootfile, traverse as root object only *)
		rootObject.nextRoot := rootList; rootList := rootObject;	(* link root list *)
	END;
END AddRootObject;

(* interruptible garbage collector for native A2 *)
PROCEDURE CollectGarbage*(root : RootObject);
VAR
	obj: RootObject;
	time1, time2: HUGEINT;
	f: FreeBlock;
	i: LONGINT;
BEGIN
	 (* do never use any low level locks as the garbage collector process has a very high priority and may thus be blocked by lower level processes -> potential deadlock *)
	(*!
	Do not use windows functionality such as  trace here in general -- can lead to deadlock when stopped processes are in writing to a file
	*)
	(* GC may run only if and only if sweep phase has been completed *)
	IF ~EnableFreeLists OR (sweepMemBlock = NIL) & (sweepMarkValue = currentMarkValue) THEN
		IF Stats THEN
			Nmark := 0; Nmarked := 0;
			INC(Ngc);
			time1 := Machine.GetTimer ();
		END;
		numCandidates := 0;
		rootList := NIL;
		INC(currentMarkValue, GenerationMask);

		FOR i := 0 TO currentGeneration DO
			generationMarkValues[i] := currentMarkValue;
		END;
		(* TRACE(currentGeneration); *)
		IF currentGeneration = Young THEN
			(* sweep and enter all old blocks containing old -> new pointers *)
			SweepCardSet();
		END; 
		ClearCardSet();

		AddRootObject(root);

		IF GCType = HeuristicStackInspectionGC THEN

			REPEAT
				REPEAT
					IF rootList # NIL THEN	(* check root objects *)
						REPEAT
							obj := rootList;					(* get head object *)
							rootList := rootList.nextRoot;		(* link to next *)
							obj.FindRoots; (* Mark called via AddRootObject, but not for objects in static heap *)
						UNTIL rootList = NIL
					END;
					IF numCandidates # 0 THEN CheckCandidates END
				UNTIL (numCandidates = 0) & (rootList = NIL);
				MarkRealtimeObjects;
				CheckFinalizedObjects;
			UNTIL rootList = NIL;

		ELSIF GCType = MetaDataForStackGC THEN
			REPEAT
				IF rootList # NIL THEN	(* check root objects *)
					REPEAT
						obj := rootList;					(* get head object *)
						rootList := rootList.nextRoot;		(* link to next *)
						obj.FindRoots; (* Mark called via AddRootObject, but not for objects in static heap *)
					UNTIL rootList = NIL
				END;
				MarkRealtimeObjects;
				CheckFinalizedObjects
			UNTIL rootList = NIL;

		ELSE
			HALT(901)	(* wrong GCType constant *)
		END;

		IF Stats THEN
			time2 := Machine.GetTimer ();
			NgcCyclesLastRun := time2 - time1;
			IF NgcCyclesLastRun > NgcCyclesMax THEN NgcCyclesMax := NgcCyclesLastRun; END;
			INC(NgcCyclesAllRuns, NgcCyclesLastRun);
			NgcCyclesMark := NgcCyclesLastRun
		END;
		(* TRACE(LONGINT((time2-time1) DIV (1024*1024))); *)
	END;

	IF EnableFreeLists THEN GetFreeBlock(MAX(SIZE), f) END;

END CollectGarbage;

PROCEDURE InvokeGC*;
BEGIN
	ASSERT(gcStatus # NIL);
	gcStatus.SetgcOngoing(TRUE);
END InvokeGC;

PROCEDURE ReturnBlocks;
VAR memBlock {UNTRACED}, free{UNTRACED}: Machine.MemoryBlock; p: ADDRESS; heapBlock {UNTRACED}: HeapBlock; f: FreeBlock;
BEGIN
	GetFreeBlock(MAX(SIZE), f);
	memBlock := Machine.memBlockHead;
	WHILE memBlock # NIL DO
		free := NIL;
		p := memBlock.beginBlockAdr;
		heapBlock := SYSTEM.VAL(HeapBlock, p + BlockHeaderSize);
		IF (heapBlock IS FreeBlock)  & (p + heapBlock.size = memBlock.endBlockAdr)  THEN
			free := memBlock;
		END;
		memBlock := memBlock.next;
		IF free # NIL THEN
			Machine.FreeMemBlock(free)
		END;
	END;
	sweepMemBlock := NIL; (* restart LazySweep  *)
	ClearFreeLists;
END ReturnBlocks;

(* 
	caller must hold the Heaps lock 
	required for low level tracing
*)
PROCEDURE FullSweep*;
VAR p {UNTRACED}: FreeBlock;
BEGIN
	GetFreeBlock(MAX(SIZE), p);
END FullSweep;

PROCEDURE LazySweepGC*;
VAR p {UNTRACED}: FreeBlock;
BEGIN
	(* invoke mark phase, mark phase starts at next scheduler interrupt *)
	GC;
	(* return blocks now *)
	Machine.Acquire(Machine.Heaps);
	(* trying to satisfy a request of MAX(SIZE) bytes will never succeed - lazy sweep runs until end of heap *)
	GetFreeBlock(MAX(SIZE), p);
	IF EnableReturnBlocks THEN ReturnBlocks END;
	Machine.Release(Machine.Heaps);
END LazySweepGC;

VAR youngCounts: LONGINT; 

(* initialize a free heap block *)
PROCEDURE InitFreeBlock(freeBlock: FreeBlockU; mark: LONGINT; dataAdr: ADDRESS; size: SIZE);
CONST FreeBlockHeaderSize = SIZEOF(FreeBlockDesc) + BlockHeaderSize;
BEGIN
	(* initialize heap block header *)
	freeBlock.typeDesc := freeBlockTag;
	freeBlock.heapBlock := NIL;
	(* initialize heap block fields *)
	freeBlock.mark := mark + Young; 
	freeBlock.dataAdr := dataAdr;
	freeBlock.size := size;
	(* initialize free block fields *)
	freeBlock.next := NIL;
END InitFreeBlock;

VAR throughput := 0 : SIZE;

(* NewBlock - Allocate a heap block. {(size MOD BlockSize = 0)}. Caller must hold Heap lock. *)
PROCEDURE NewBlock(size: SIZE): ADDRESS;
VAR try: LONGINT; p: FreeBlock; freeBlock : FreeBlockU; memBlock {UNTRACED}: Machine.MemoryBlock;
	beginHeapBlockAdr, endHeapBlockAdr: ADDRESS;

	PROCEDURE CheckPostGC;
	BEGIN
		IF (sweepMarkValue < currentMarkValue) & EnableReturnBlocks THEN (* GC has run but no Sweep yet -- time to do post-gc cleanup *)
			ReturnBlocks
		END;
	END CheckPostGC;

BEGIN
	CheckPostGC;
	try := 1;
	p := NIL;
	IF  (GC = NilGC) OR (throughput < 32*1024*1024) THEN
		GetFreeBlock(size, p);
		IF  (p=NIL) THEN (* try restart sweep for once *)
			GetFreeBlock(size, p);
		END;
	ELSE
		throughput := 0;
	END;

	
	WHILE (p = NIL) & (try <= MaxTries) DO
		IF currentGeneration = Young THEN INC(youngCounts) END;
		IF youngCounts > 100 THEN 
			currentGeneration := Old;
		END;
		Machine.Release(Machine.Heaps);	(* give up control *)
		GC;	(* try to free memory (other processes may also steal memory now) *)
		Machine.Acquire(Machine.Heaps);
		CheckPostGC;
		sweepMemBlock := NIL;
		GetFreeBlock(size, p);
		IF (currentGeneration = Young) & (p=NIL) THEN
			currentGeneration := Old;
			Machine.Release(Machine.Heaps);	(* give up control *)
			GC;	(* try to free memory (other processes may also steal memory now) *)
			Machine.Acquire(Machine.Heaps);
			CheckPostGC;
			currentGeneration := Young;
			sweepMemBlock := NIL;
			GetFreeBlock(size, p);
		END;		
		IF youngCounts > 100 THEN 
			currentGeneration := Young;
			youngCounts := 0;
		END;
		IF p = NIL THEN
			Machine.ExpandHeap(try, size, memBlock, beginHeapBlockAdr, endHeapBlockAdr);	(* try to extend the heap *)
			IF endHeapBlockAdr > beginHeapBlockAdr THEN
				freeBlock := beginHeapBlockAdr + BlockHeaderSize;
				InitFreeBlock(freeBlock, Unmarked, NilVal, endHeapBlockAdr - beginHeapBlockAdr);
				Machine.SetMemoryBlockEndAddress(memBlock, endHeapBlockAdr); (* end address of expanded block must set after free block is fit in memory block *)
				IF EnableFreeLists THEN AppendFreeBlock(freeBlock)
				ELSE
				sweepMemBlock := memBlock;
				sweepBlockAdr := beginHeapBlockAdr;
				END;
				GetFreeBlock(size, p);
				sweepMemBlock := NIL; (* restart sweep from beginning after having taken big block in order to avoid fragmentation *)
			END;
			INC(try)
		END;
	END;
	IF p # NIL THEN
		IF Stats THEN INC(Nnew); INC(NnewBytes, size) END;
		ASSERT(p.size >= size);
		RETURN p;
	ELSE 	(* try = MaxTries *)
		SYSTEM.HALT(14) 	(* out of memory *)
	END;
END NewBlock;

PROCEDURE CheckBP(bp: ADDRESS): ADDRESS;
VAR n: ADDRESS;
BEGIN
	SYSTEM.GET(bp,n);
	IF ODD(n) THEN  bp := bp + SIZEOF(ADDRESS) END;
	RETURN bp;
END CheckBP;

PROCEDURE SetPC*(p: DataBlockU);
VAR bp: ADDRESS;
BEGIN
	IF p # NIL THEN
		bp := CheckBP(Machine.CurrentBP()); 
		SYSTEM.GET(bp, bp); 
		bp := CheckBP(bp);
		SYSTEM.GET(bp+SIZEOF(ADDRESS), p.heapBlock.heapBlock);
	END;
END SetPC;

(** NewSys - Implementation of SYSTEM.NEW. *)
PROCEDURE NewSys*(VAR p: ANY; size: SIZE; isRealtime: BOOLEAN);
VAR 
	blockSize, systemBlockSize: SIZE; systemBlockAdr, dataBlockAdr: ADDRESS;
	systemBlock: HeapBlockU;
	dataBlock: DataBlockU;
BEGIN
	systemBlockSize := BlockHeaderSize + SIZEOF(SystemBlockDesc);
	INC(systemBlockSize, (-systemBlockSize) MOD ArrayAlignment); (* round up to multiple of ArrayAlignment to ensure alignment of first data element to 0 MOD ArrayAlignment *)
	blockSize := systemBlockSize + BlockHeaderSize + size;
	INC(blockSize, (-blockSize) MOD BlockSize);  (* round up to multiple of BlockSize *)

	Machine.Acquire(Machine.Heaps);
	systemBlockAdr:= NewBlock(blockSize);
	IF systemBlockAdr # 0 THEN
		systemBlock := systemBlockAdr;
		dataBlockAdr := systemBlockAdr + systemBlockSize;
		dataBlock := dataBlockAdr;
		systemBlock.typeDesc := systemBlockTag;
		dataBlock.typeDesc := NilVal;
		dataBlock.heapBlock := systemBlock;
		systemBlock.mark := currentMarkValue + Young;
		systemBlock.dataAdr := dataBlockAdr;
		systemBlock.size := blockSize;
		(*! disable realtime block handling for the time being
		IF isRealtime THEN
			systemBlock.nextRealtime := realtimeList;
			realtimeList := systemBlock
		ELSE
			systemBlock.nextRealtime := NIL
		END;
		*)
		SetPC(dataBlock);
		p := dataBlock;
		(* clear could be done outside lock because SysBlks are not traced, but for conformity it is done inside the lock *)
		Machine.Fill32(dataBlockAdr, blockSize - systemBlockSize - BlockHeaderSize, 0);	(* clear everything from dataBlockAdr until end of block *)
	ELSE
		p := NIL
	END;
	IF allocationLogger # NIL THEN allocationLogger(p) END;
	Machine.Release(Machine.Heaps)
END NewSys;

(** NewRec - Implementation of NEW with a record. *)
PROCEDURE NewRec*(VAR p: ANY; tag: ADDRESS; isRealtime: BOOLEAN);
VAR 
	size, blockSize: SIZE; recordBlockAdr, dataBlockAdr : ADDRESS;
	recordBlock: RecordBlockU;
	dataBlock: DataBlockU;
	typeDesc: StaticTypeBlockU;
BEGIN
	typeDesc := tag;
	IF ProtTypeBit IN typeDesc.info.flags THEN
		NewProtRec(p, tag, isRealtime);
		SetPC(p);
	ELSE
		size := typeDesc.recSize;
		(* the block size is the sum of the size of the RecordBlock and the DataBlock.
		    Two extra fields per subblock contain the tag and the reference to the heap block *)
		blockSize := BlockHeaderSize + SIZEOF(RecordBlockDesc) + BlockHeaderSize + size;
		INC(blockSize, (-blockSize) MOD BlockSize); 	(* round up to multiple of BlockSize *)

		Machine.Acquire(Machine.Heaps);
		recordBlockAdr := NewBlock(blockSize);
		IF recordBlockAdr # 0 THEN
			recordBlock := recordBlockAdr;
			dataBlockAdr := recordBlockAdr + SIZEOF(RecordBlockDesc) + BlockHeaderSize;
			dataBlock := dataBlockAdr;
			recordBlock.typeDesc := recordBlockTag;
			dataBlock.typeDesc := tag;
			dataBlock.heapBlock := recordBlockAdr;
			recordBlock.mark := currentMarkValue + Young;
			recordBlock.dataAdr := dataBlockAdr;
			recordBlock.size := blockSize; 
			
			(*! disable realtime block handling for the time being
			IF isRealtime THEN
				recordBlock.nextRealtime := realtimeList;
				realtimeList := recordBlock
			ELSE
				recordBlock.nextRealtime := NIL
			END;
			*)
			
			SetPC(dataBlock);
			p := dataBlock; 
			IF (currentGeneration = Young) OR (youngCounts > 0) THEN
				EnterInCardSet(ADDRESS OF p);
			END;

			(* clear must be done inside lock to ensure all traced pointer fields are initialized to NIL *)
			Machine.Fill32(dataBlockAdr, blockSize - SIZEOF(RecordBlockDesc) - 2 * BlockHeaderSize, 0);	(* clear everything from dataBlockAdr until end of block *)
		ELSE
			p := NIL
		END;
		IF allocationLogger # NIL THEN allocationLogger(p) END;
		Machine.Release(Machine.Heaps)
	END;
END NewRec;

(** NewProtRec - Implementation of NEW with a protected record. *)
PROCEDURE NewProtRec*(VAR p: ANY; tag: ADDRESS; isRealtime: BOOLEAN);
VAR size, blockSize: SIZE; protRecBlockAdr, dataBlockAdr: ADDRESS;
	protRecBlock: ProtRecBlockU;
	dataBlock: DataBlockU;
	i: LONGINT; 
	typeDesc: StaticTypeBlockU;
BEGIN
	typeDesc := tag;
	size := typeDesc.recSize;
	blockSize := BlockHeaderSize + SIZEOF(ProtRecBlockDesc) + BlockHeaderSize + size;
	INC(blockSize, (-blockSize) MOD BlockSize); (* round up to multiple of BlockSize *)

	Machine.Acquire(Machine.Heaps);
	protRecBlockAdr := NewBlock(blockSize);
	IF protRecBlockAdr # 0 THEN
		protRecBlock := protRecBlockAdr;
		dataBlockAdr := protRecBlockAdr + SIZEOF(ProtRecBlockDesc) + BlockHeaderSize;
		dataBlock := dataBlockAdr;
		protRecBlock.typeDesc := protRecBlockTag;
		dataBlock.typeDesc := tag;
		dataBlock.heapBlock := protRecBlockAdr;
		protRecBlock.mark := currentMarkValue + Young;
		protRecBlock.dataAdr := dataBlockAdr;
		protRecBlock.size := blockSize;
		(*! disable realtime block handling for the time being
		IF isRealtime THEN
			protRecBlock.nextRealtime := realtimeList;
			realtimeList := protRecBlock
		ELSE
			protRecBlock.nextRealtime := NIL
		END;
		*)
		protRecBlock.count := 0;
		protRecBlock.awaitingLock.head := NIL;
		protRecBlock.awaitingLock.tail := NIL;
		protRecBlock.awaitingCond.head := NIL;
		protRecBlock.awaitingCond.tail := NIL;
		protRecBlock.lockedBy := NIL;
		protRecBlock.locked := FALSE;
		protRecBlock.lock := NIL;
		FOR i := 0 TO NumPriorities - 1 DO
			protRecBlock.waitingPriorities[i] := 0
		END;
		INC(protRecBlock.waitingPriorities[0]);	(* set sentinel value: assume that idle process with priority 0 waits on this resource *)
		
		SetPC(dataBlock);
		p := dataBlock; 
		IF (currentGeneration = Young) OR (youngCounts > 0) THEN
			EnterInCardSet(ADDRESS OF p);
		END;

		(* clear must be done inside lock to ensure all traced pointer fields are initialized to NIL *)
		Machine.Fill32(dataBlockAdr, blockSize - SIZEOF(ProtRecBlockDesc) - 2 * BlockHeaderSize, 0);	(* clear everything from dataBlockAdr to end of block *)
	ELSE
		p := NIL
	END;
	IF allocationLogger # NIL THEN allocationLogger(p) END;
	Machine.Release(Machine.Heaps)
END NewProtRec;


(** NewArr - Implementation of NEW with an array containing pointers. *)
PROCEDURE NewArr*(VAR p: ANY; elemTag: ADDRESS;  numElems, numDims: SIZE; isRealtime: BOOLEAN);
VAR arrayBlockAdr, dataBlockAdr: ADDRESS; 
	elemSize, arrSize, blockSize, arrayBlockSize, fillSize, size, arrayDataOffset: SIZE;
	firstElem: ADDRESS; 
	ptrOfs: ADDRESS; 
	elemType: StaticTypeBlockU;
	arrayBlock: ArrayBlockU;
	dataBlock: ArrayDataBlockU;
BEGIN
	elemType := elemTag;
	elemSize := elemType.recSize;
	arrSize := numElems * elemSize;
	
	IF arrSize = 0 THEN
		NewSys(p, numDims * AddressSize + 3 * AddressSize, isRealtime); (* no data, thus no specific alignment *)
		SetPC(p);
	ELSE
		ASSERT(BlockHeaderSize MOD ArrayAlignment = 0);
		arrayDataOffset := numDims * AddressSize + 3 * AddressSize;
		INC(arrayDataOffset, (-arrayDataOffset) MOD ArrayAlignment);  (* round up to multiple of ArrayAlignment to ensure that first array element is aligned at 0 MOD ArrayAlignment *)
		ptrOfs := elemType.pointerOffsets;
		IF ptrOfs = MinPtrOfs - AddressSize THEN (* no pointers in element type *)
			size := arrayDataOffset + arrSize;
			NewSys(p, size, isRealtime);
			SetPC(p);
		ELSE
			arrayBlockSize := BlockHeaderSize + SIZEOF(ArrayBlockDesc);
			INC(arrayBlockSize, (-arrayBlockSize) MOD ArrayAlignment); (* do. *)
			blockSize := arrayBlockSize + BlockHeaderSize + (arrayDataOffset + arrSize);
			INC(blockSize, (-blockSize) MOD BlockSize); (* round up to multiple of BlockSize *)
			Machine.Acquire(Machine.Heaps);
			arrayBlockAdr := NewBlock(blockSize);
			IF arrayBlockAdr # 0 THEN
				arrayBlock := arrayBlockAdr;
				dataBlockAdr := arrayBlockAdr + arrayBlockSize (* - BlockHeaderSize + BlockHeaderSize *);
				dataBlock := dataBlockAdr; 
				arrayBlock.typeDesc := arrayBlockTag;
				dataBlock.typeDesc := elemType;
				dataBlock.heapBlock := arrayBlock; 
				arrayBlock.mark := currentMarkValue + Young;
				arrayBlock.dataAdr := dataBlockAdr;
				arrayBlock.size := blockSize;

				(*! disable realtime block handling for the time being
				IF isRealtime THEN
					arrayBlock.nextRealtime := realtimeList;
					realtimeList := arrayBlock
				ELSE
					arrayBlock.nextRealtime := NIL
				END;
				*)

				(* clear data part of array here, since size parameter of Machine.Fill32 must be a multiple of 4. Some fields of the data part are filled below for GC. , *)
				fillSize := blockSize - arrayBlockSize - BlockHeaderSize;
				Machine.Fill32(dataBlockAdr, fillSize, 0); 	(* clear everything from dataBlockAdr until end of block *)
				
				firstElem := dataBlockAdr + arrayDataOffset;
				dataBlock.numElems := numElems;
				dataBlock.current := NIL;
				dataBlock.first := firstElem;

				SetPC(dataBlock); 
				p := dataBlock; 
				IF (currentGeneration = Young) OR (youngCounts > 0) THEN
					EnterInCardSet(ADDRESS OF p);
				END;
			ELSE
				p := NIL
			END;
			IF allocationLogger # NIL THEN allocationLogger(p) END;
			Machine.Release(Machine.Heaps)
		END
	END
END NewArr;

TYPE
UnsafeArray= POINTER {UNSAFE,UNTRACED} TO UnsafeArrayDesc;
UnsafeArrayDesc = RECORD (ArrayDataBlockDesc)
	len: ARRAY 8 OF SIZE;
END;

(* replacement for overcomplicated code emission -- at the cost of a slightly increased runtime cost *)
PROCEDURE NewArray*(CONST a: ARRAY OF SIZE;  tag: ADDRESS; staticElements, elementSize: SIZE; VAR dest: ANY);
VAR p: ANY; dim: SIZE;
		
		PROCEDURE GetSize(): SIZE;
		VAR i: SIZE; size: SIZE;
		BEGIN
			size := 1;
			FOR i := 0 TO dim-1 DO
				size := size * a[i];
			END;
			RETURN size*staticElements;
		END GetSize;
		
		PROCEDURE SetSizes(dest: UnsafeArray);
		VAR i: SIZE;
		BEGIN
			FOR i := 0 TO dim-1 DO
				dest.len[i] := a[dim-1-i];
			END;
		END SetSizes;

	BEGIN
		(* static elements is requred for this case : POINTER TO ARRAY OF ARRAY X OF RecordWithPointer *)
		dim := LEN( a,0 );
		IF tag = NIL THEN
			NewSys(p, GetSize() * elementSize + dim * SIZEOF(ADDRESS) + 3 *SIZEOF(ADDRESS) + (dim DIV 2) * 2 * SIZEOF(ADDRESS), FALSE);
		ELSE
			NewArr(p, tag, GetSize(), dim, FALSE);
		END;
		SetSizes(p);
		SetPC(p);
		dest := p;
		IF (currentGeneration = Young) OR (youngCounts > 0) THEN
			EnterInCardSet(ADDRESS OF dest);
		END;
END NewArray;


(* obsolete for generic object file / required only for old loader *)
PROCEDURE FillStaticType*(VAR staticTypeAddr: ADDRESS; startAddr, typeInfoAdr: ADDRESS; size, recSize: SIZE;
							numPtrs, numSlots: LONGINT);
VAR p, offset: ADDRESS; staticTypeBlock {UNTRACED}: StaticTypeBlock;
BEGIN
	Machine.Acquire(Machine.Heaps);

	Machine.Fill32(startAddr, size, 0);	(* clear whole static type, size MOD AddressSize = 0 implicitly, see WriteType in PCOF.Mod *)
	SYSTEM.PUT(startAddr, MethodEndMarker);	(* sentinel *)

	(* methods and tags filled in later *)

	offset := AddressSize * (numSlots + 1 + 1);  (* #methods, max. no. of tags, method end marker (sentinel), pointer to type information*)
	p := startAddr + offset;
	SYSTEM.PUT(p + TypeDescOffset, typeInfoAdr); 	(* pointer to typeInfo *)
	staticTypeBlock := SYSTEM.VAL(StaticTypeBlock, p);
	staticTypeBlock.recSize := recSize;
	staticTypeAddr := p;

	(* create the pointer for the dynamic array of pointer offsets, the dynamic array of pointer offsets is stored in the static type
	    descriptor, it has no header part *)
	INC(p, SIZEOF(StaticTypeDesc));
	IF p MOD (2 * AddressSize) # 0 THEN INC(p, AddressSize) END;
	SYSTEM.PUT(p + 3 * AddressSize, numPtrs); (* internal structure of dynamic array without pointers: the first 3 fields are unused *)
	staticTypeBlock.pointerOffsets := SYSTEM.VAL(PointerOffsets, p); (* the fourth field contains the dimension of the array *)

	(* pointer offsets  filled in later *)

	Machine.Release(Machine.Heaps)
END FillStaticType;

PROCEDURE AddFinalizer*(obj: ANY; n: FinalizerNode);
BEGIN
	n.objWeak := obj; n.objStrong := NIL; n.finalizerStrong := NIL;
	Machine.Acquire(Machine.Heaps);
	n.nextFin := checkRoot; checkRoot := n;
	IF Stats THEN INC(NfinalizeAlive) END;
	Machine.Release(Machine.Heaps)
END AddFinalizer;

(** Compute total heap size, free space and largest free block size in bytes. This is a slow operation. *)
PROCEDURE GetHeapInfo*(VAR total, free, largest: SIZE);
VAR memBlock {UNTRACED}: Machine.MemoryBlock; blockAdr: ADDRESS;
	block {UNTRACED}: HeapBlock;
BEGIN
	Machine.Acquire(Machine.Heaps);
	memBlock := Machine.memBlockHead;
	total := 0; free := 0; largest := 0;
	WHILE memBlock # NIL DO
		total := total + memBlock.endBlockAdr - memBlock.beginBlockAdr;
		blockAdr := memBlock.beginBlockAdr;
		WHILE blockAdr < memBlock.endBlockAdr DO
			block := SYSTEM.VAL(HeapBlock, blockAdr + BlockHeaderSize); (* get heap block *)
			IF (block.mark < currentMarkValue) THEN (* free/unused block encountered *)
				free := free + block.size;
				IF ADDRESS(block.size) > ADDRESS(largest) THEN largest := block.size END
			END;
			blockAdr := blockAdr + block.size;
		END;
		memBlock := memBlock.next
	END;
	Machine.Release(Machine.Heaps)
END GetHeapInfo;

(* redundant, for compatibility *)
PROCEDURE HeapSize*(): SIZE;
VAR total, free, largest: SIZE;
BEGIN
	GetHeapInfo(total, free, largest);
	RETURN total;
END HeapSize;

(* redundant, for compatibility *)
PROCEDURE Used*(): SIZE;
VAR total, free, largest: SIZE;
BEGIN
	GetHeapInfo(total, free, largest);
	RETURN total-free;
END Used;

VAR assigns*: LONGINT;

PROCEDURE Assign*(VAR dest: ADDRESS; src: ADDRESS);
BEGIN
	CheckAssignment(ADDRESS OF dest,src);
	dest := src;
	INC(assigns);
END Assign;

PROCEDURE AssignRecord*(dest: ADDRESS; tag: StaticTypeBlockU; src: ADDRESS);
VAR i: LONGINT; sval: ADDRESS;
BEGIN
	FOR i := 0 TO LEN(tag.pointerOffsets)-1 DO
		SYSTEM.GET(src+tag.pointerOffsets[i], sval);
		CheckAssignment(dest + tag.pointerOffsets[i], sval); 
	END;
	SYSTEM.MOVE(src,dest,tag.recSize);
	INC(assigns);
END AssignRecord;

PROCEDURE AssignArray*(dest: ADDRESS; tag: StaticTypeBlockU;  numElems: SIZE; src: ADDRESS);
VAR i, j: SIZE; sval: ADDRESS; 
BEGIN
	FOR j := 0 TO LEN(tag.pointerOffsets)-1 DO
	FOR i := 0 TO numElems-1 DO
		SYSTEM.GET(src+tag.pointerOffsets[i] + i * tag.recSize + tag.pointerOffsets[j], sval);
		CheckAssignment(dest+ i * tag.recSize + tag.pointerOffsets[j], sval);
	END;
	END;
	SYSTEM.MOVE(src,dest,tag.recSize * numElems);
	INC(assigns);	
END AssignArray;

(* NilGC - Default garbage collector. *)
PROCEDURE NilGC;
BEGIN
	HALT(301)	(* garbage collector not available yet *)
END NilGC;

(* Init - Initialize the heap. *)
PROCEDURE Init;
VAR beginBlockAdr, endBlockAdr, freeBlockAdr, p: ADDRESS;
	heapBlock: HeapBlockU; freeBlock: FreeBlockU; memBlock {UNTRACED}: Machine.MemoryBlock;
	s: ARRAY 32 OF CHAR; minSize,i: LONGINT;
BEGIN
	Machine.GetConfig("EnableFreeLists", s);
	EnableFreeLists := (s[0] = "1");
	Machine.GetConfig("EnableReturnBlocks", s);
	EnableReturnBlocks := (s[0] = "1");
	IF EnableReturnBlocks THEN Trace.String("Heaps:ReturnBlocks enabled"); Trace.Ln END;
	Machine.GetConfig("TraceHeaps",s);
	trace := (s[0] = "1");

	minSize := 32;
	FOR i := 0 TO MaxFreeLists DO
		freeLists[i].minSize := minSize;
		freeLists[i].first := NIL; freeLists[i].last := NIL;
		IF i < FreeListBarrier THEN  INC( minSize, BlockSize )  ELSE  minSize := 2 * minSize  END
	END;

	GC := NilGC;
	newSum := 0;
	checkRoot := NIL; finalizeRoot := NIL; rootList := NIL; realtimeList := NIL;
	gcStatus := NIL;

	Machine.SetGCParams;
	Machine.GetStaticHeap(beginBlockAdr, endBlockAdr, freeBlockAdr);

	(* the Type desciptor is generated by the compiler, therefore the linker does not have to patch anything any more *)
	
	freeBlockTag := SYSTEM.TYPECODE (FreeBlockDesc);
	systemBlockTag := SYSTEM.TYPECODE (SystemBlockDesc);
	recordBlockTag := SYSTEM.TYPECODE (RecordBlockDesc);
	protRecBlockTag := SYSTEM.TYPECODE (ProtRecBlockDesc);
	arrayBlockTag := SYSTEM.TYPECODE (ArrayBlockDesc);
	
	(* find last block in static heap *)
	p := beginBlockAdr;
	heapBlock := SYSTEM.VAL(HeapBlock, p + BlockHeaderSize);
	WHILE p < freeBlockAdr DO
		initBlock := SYSTEM.VAL(ANY, heapBlock.dataAdr);
		p := p + heapBlock.size;
		heapBlock := SYSTEM.VAL(HeapBlock, p + BlockHeaderSize)
	END;

	ASSERT(p = freeBlockAdr);
	IF endBlockAdr - freeBlockAdr > 0 THEN
		(* initialization of free heap block done here since boot file is only written up to freeBlockAdr *)
		freeBlock := freeBlockAdr + BlockHeaderSize;
		InitFreeBlock(freeBlock, Unmarked, NilVal, endBlockAdr - freeBlockAdr);
		IF EnableFreeLists THEN AppendFreeBlock(freeBlock) END;
		ASSERT(freeBlock.size MOD BlockSize  =  0)
	END;

	currentMarkValue := GenerationMask;
	currentGeneration := Old;
	FOR i := 0 TO currentGeneration DO
		generationMarkValues[i] := currentMarkValue;
	END;

	(* extend the heap for one block such that module initialization can continue as long as Heaps.GC is not set validly *)
	Machine.ExpandHeap(1, 1, memBlock, beginBlockAdr, endBlockAdr);	(* try = 1, size = 1 -> the minimal heap block expansion is performed *)
	IF endBlockAdr > beginBlockAdr THEN
		freeBlock := beginBlockAdr + BlockHeaderSize;
		InitFreeBlock(freeBlock, Unmarked, NilVal, endBlockAdr - beginBlockAdr);
		Machine.SetMemoryBlockEndAddress(memBlock, endBlockAdr);
		IF EnableFreeLists THEN AppendFreeBlock(freeBlock) END;
		sweepMarkValue := currentMarkValue;
		sweepMemBlock := memBlock;
		sweepBlockAdr := beginBlockAdr
	END;

END Init;

PROCEDURE SetYoung*;
BEGIN
	Machine.Acquire(Machine.Heaps);
	currentGeneration := Young;
	Machine.Release(Machine.Heaps);
END SetYoung;

PROCEDURE SetOld*;
BEGIN
	Machine.Acquire(Machine.Heaps);
	currentGeneration := Old;
	Machine.Release(Machine.Heaps);
END SetOld;



PROCEDURE SetHeuristic*;
BEGIN
	GCType := HeuristicStackInspectionGC;
	Trace.String("GC mode : heuristic"); Trace.Ln;
END SetHeuristic;

PROCEDURE SetMetaData*;
BEGIN
	GCType := MetaDataForStackGC;
	Trace.String("GC mode : metadata"); Trace.Ln;
END SetMetaData;

BEGIN
	(* The meta data stack inspection is more efficient than the heuristics *)
	GCType := HeuristicStackInspectionGC;
	Init;
END Heaps.


(*
TraceHeap:
0	1	NR NEW record
1	2	NA/NV NEW array
2	4	NS SYSTEM.NEW
3	8	DR deallocate record #
4	16	DA deallocate array #
5	32	DS deallocate sysblk #
6	64	NT NewType
7	128
8	256	FB show free blocks #
9	512	DP deallocate protrec #
10	1024	finalizers
11	2048	live/dead #
12 4096 trace mark stack overflows #

# influences timing
*)

(*
20.03.1998	pjm	Started
17.08.1998	pjm	FindRoots method
18.08.1998	pjm	findPossibleRoots removed, use FindRoots method
09.10.1998	pjm	NewRec with page alignment
21.01.1999	pjm	Mark adapted for AosBuffers
26.01.1999	pjm	Incorporated changes for new compiler
10.11.2000	pjm	Finalizers
26.01.2001	pjm	Removed trapReserve, reimplemented NewBlock
11.11.2004	lb	   Garbage collector with marking stack
19.06.2007	ug	Garbage collector using meta data for stack inspection (cf. Objects)
11.07.2008 	ug	new heap data structures and adaption to GC
*)

Co


Compiler.Compile -p=Win32G --writeBarriers --traceModule=Trace
Runtime.Mod Trace.Mod Generic.Win32.Kernel32.Mod Win32.Machine.Mod Heaps.Mod 
Generic.Modules.Mod Win32.Objects.Mod Win32.Kernel.Mod KernelLog.Mod Plugins.Mod Streams.Mod Pipes.Mod 
Commands.Mod I386.Reals.Mod Generic.Reflection.Mod
Win32.Traps.Mod Win32.WinTrace.Mod Win32.StdIO.Mod Locks.Mod Win32.Clock.Mod Disks.Mod Files.Mod 
Dates.Mod Strings.Mod UTF8Strings.Mod FileTrapWriter.Mod Caches.Mod DiskVolumes.Mod 
OldDiskVolumes.Mod RAMVolumes.Mod DiskFS.Mod OldDiskFS.Mod OberonFS.Mod FATVolumes.Mod FATFiles.Mod 
ISO9660Volumes.Mod ISO9660Files.Mod Win32.User32.Mod Win32.WinTrace.Mod Win32.ODBC.Mod 
Win32.Shell32.Mod Win32.SQL.Mod Win32.WinFS.Mod RelativeFileSystem.Mod BitSets.Mod Diagnostics.Mod 
StringPool.Mod ObjectFile.Mod GenericLinker.Mod GenericLoader.Mod BootConsole.Mod 

~

Compiler.Compile -p=Win32G --traceModule=Trace --writeBarriers Heaps.Mod ~
StaticLinker.Link --fileFormat=PE32 --fileName=A2.exe --extension=GofW --displacement=401000H Runtime Trace Kernel32 Machine Heaps Modules Objects Kernel KernelLog Streams Commands FIles WinFS Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker Reflection  GenericLoader  BootConsole ~
FSTools.CloseFiles A2.exe ~


FoxBinarySymbolFile.Test /temp/obj/Heaps ~

Heaps.ShowCards 

(* enable generational garbage collection *)
Heaps.SetYoung 
(* disable generational garbage collection *)
Heaps.SetOld 

Kernel.GC

SystemTools.ModuleState Heaps ~
