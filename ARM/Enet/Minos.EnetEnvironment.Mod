MODULE EnetEnvironment;
(**
	AUTHOR: Alexey Morozov, HighDim GmbH, 2015
	PURPOSE: Ethernet networking stack, MINOS - specific environment
*)

IMPORT
	Board, Interrupts, GlobalTimer, Caches, UncachedHeap, Trace;

CONST
	MaxHandlers = 32;

TYPE
	Time* = HUGEINT; (* Time type used in EnetTiming *)
	
	(* The prototype of an interrupt handler *)
	InterruptHandler* = PROCEDURE();

	(** Uncached memory descriptor *)
	UncachedMemDesc* = RECORD
		addr-: ADDRESS; (** starting address of the uncached memory available to the user *)
		length-: SIZE; (** length of the uncached memory region available to the user; can be greater than the value passed to AllocateUncachedMemory *)
	END;

VAR
	TraceString-: PROCEDURE(CONST str: ARRAY OF CHAR);
	GetTimeCounter-: PROCEDURE(): Time;
	InvalidateDCacheRange-: PROCEDURE(addr: ADDRESS; length: SIZE);
	FlushDCacheRange-: PROCEDURE(addr: ADDRESS; length: SIZE);
	handlers: ARRAY MaxHandlers OF RECORD handle: PROCEDURE; irq: LONGINT END;

	(**
		Install an interrupt handler
	*)
	PROCEDURE InstallInterruptHandler*(interruptHandler: InterruptHandler; interruptNumber: LONGINT);
	VAR
		i: LONGINT;
	BEGIN
		i := 0;
		WHILE (i < MaxHandlers) & (handlers[i].handle # NIL) DO INC(i) END;
		handlers[i].handle := interruptHandler;
		handlers[i].irq := interruptNumber;
		Interrupts.InstallHandler(HandleInterrupt,interruptNumber);
	END InstallInterruptHandler;

	(**
		Allocate length bytes of uncached memory
	*)
	PROCEDURE AllocateUncachedMemory*(length: SIZE; VAR memDesc: UncachedMemDesc);
	BEGIN
		ASSERT(memDesc.addr = NIL);
		memDesc.addr := UncachedHeap.New(length);
		memDesc.length := length;
	END AllocateUncachedMemory;

	(**
		Dispose uncached memory
	*)
	PROCEDURE DisposeUncachedMemory*(VAR memDesc: UncachedMemDesc);
	BEGIN
		ASSERT(memDesc.addr # NIL);
		memDesc.addr := NIL;
		memDesc.length := 0;
	END DisposeUncachedMemory;

	(** Convert microseconds to time counts *)
	PROCEDURE FromMicro*(us: Time): Time;
	BEGIN
		RETURN us * ENTIERH(0.5D0+Board.CpuClockHz/2.0D6);
	END FromMicro;

	(** Convert time counts to microseconds *)
	PROCEDURE ToMicro*(time: Time): Time;
	BEGIN
		RETURN ENTIERH((0.5D0 + time) / (LONGREAL(Board.CpuClockHz)) * 2.0D6)
	END ToMicro;

	(** Convert milliseconds to time counts *)
	PROCEDURE FromMilli*(ms: Time): Time;
	BEGIN
		RETURN ms * ENTIERH(0.5D0+Board.CpuClockHz/2.0D3);
	END FromMilli;

	(** Convert time counts to milliseconds *)
	PROCEDURE ToMilli*(time: Time): Time;
	BEGIN
		RETURN ENTIERH((0.5D0 + time) / (LONGREAL(Board.CpuClockHz)) * 2.0D3)
	END ToMilli;

	(** Delegating interrupt handler *)
	PROCEDURE HandleInterrupt * (irq: LONGINT);
	VAR
		i: LONGINT;
		handle: PROCEDURE;
	BEGIN
		FOR i := 0 TO MaxHandlers - 1 DO
			handle := handlers[i].handle;
			IF (handle # NIL) & (handlers[i].irq = irq) THEN handle END
		END
	END HandleInterrupt;

BEGIN
	TraceString := Trace.String;
	GetTimeCounter := GlobalTimer.GetTime;
	InvalidateDCacheRange := Caches.InvalidateDCacheRange;
	FlushDCacheRange := Caches.CleanDCacheRange;
	GlobalTimer.EnableTimer
END EnetEnvironment.
