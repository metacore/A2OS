MODULE EnetEnvironment;
(**
	AUTHOR: Alexey Morozov, HighDim GmbH, 2015
	PURPOSE: Ethernet networking stack, ARM A2 - specific environment
*)

IMPORT
	Platform, BootConfig, Machine, Objects, KernelLog;

TYPE
	Time* = SIGNED64; (* Time type used in EnetTiming *)

	(* The prototype of an interrupt handler *)
	InterruptHandler* = PROCEDURE();

	(** Uncached memory descriptor *)
	UncachedMemDesc* = RECORD
		addr-: ADDRESS; (** starting address of the uncached memory available to the user *)
		length-: SIZE; (** length of the uncached memory region available to the user; can be greater than the value passed to AllocateUncachedMemory *)

		mem: POINTER TO ARRAY OF CHAR; (* actual allocated memory block *)
	END;

VAR
	TraceString-: PROCEDURE(CONST str: ARRAY OF CHAR);
	GetTimeCounter-: PROCEDURE(): Time;
	InvalidateDCacheRange-: PROCEDURE(addr: ADDRESS; length: SIZE);
	FlushDCacheRange-: PROCEDURE(addr: ADDRESS; length: SIZE);
	cpuClockHz: SIGNED32;

	(**
		Install an interrupt handler
	*)
	PROCEDURE InstallInterruptHandler*(interruptHandler: InterruptHandler; interruptNumber: SIGNED32);
	BEGIN
		Objects.InstallHandler(interruptHandler,interruptNumber);
	END InstallInterruptHandler;

	(**
		Allocate length bytes of uncached memory
	*)
	PROCEDURE AllocateUncachedMemory*(length: SIZE; VAR memDesc: UncachedMemDesc);
	CONST
		MB = 1024*1024; (* one Mega byte *)
	BEGIN
		ASSERT(memDesc.mem = NIL);
		memDesc.length := MB*((length+MB-1) DIV MB); (* length as a multiple of MB *)
		NEW(memDesc.mem,memDesc.length+MB); (* have 1 MB reserve to be able to align to 1 MB boundary *)
		memDesc.addr := ADDRESSOF(memDesc.mem[0]);
		memDesc.addr := memDesc.addr + (MB - memDesc.addr MOD MB); (* align to 1 MB boundary *)
		ASSERT(memDesc.addr >= ADDRESSOF(memDesc.mem[0]));
		ASSERT(memDesc.addr MOD MB = 0);
		ASSERT(memDesc.addr+memDesc.length <= ADDRESSOF(memDesc.mem[LEN(memDesc.mem)-1]));
		Machine.DisableDCacheRange(memDesc.addr,memDesc.length);
	END AllocateUncachedMemory;

	(**
		Dispose uncached memory
	*)
	PROCEDURE DisposeUncachedMemory*(VAR memDesc: UncachedMemDesc);
	BEGIN
		ASSERT(memDesc.mem # NIL);
		Machine.EnableDCacheRange(memDesc.addr,memDesc.length);
		memDesc.mem := NIL;
		memDesc.addr := NIL;
		memDesc.length := 0;
	END DisposeUncachedMemory;

	(** Convert microseconds to time counts *)
	PROCEDURE FromMicro*(us: Time): Time;
	BEGIN
		RETURN us * ENTIERH(0.5D0+FLOAT64(cpuClockHz)/2.0D6);
	END FromMicro;

	(** Convert milliseconds to time counts *)
	PROCEDURE FromMilli*(ms: Time): Time;
	BEGIN
		RETURN ms * ENTIERH(0.5D0+FLOAT64(cpuClockHz)/2.0D3);
	END FromMilli;

BEGIN
	cpuClockHz := BootConfig.GetIntValue("CpuClockHz");
	TraceString := KernelLog.String;
	GetTimeCounter := Machine.GetTimer;
	InvalidateDCacheRange := Machine.InvalidateDCacheRange;
	FlushDCacheRange := Machine.FlushDCacheRange;
	
	TraceString("EnetEnvironment has been initialized!");
END EnetEnvironment.
