MODULE SdEnvironment;
(**
	AUTHOR Timothée Martiel, 2015
	PURPOSE Runtime Environment abstraction for SD Host Controller driver, A2 version
*)

IMPORT
	Machine, Objects, KernelLog, Strings, Locks, PsConfig, BootConfig;
	
TYPE
	Time* = HUGEINT; (* Time type *)

VAR
	InstallHandler *: PROCEDURE (handler: Objects.EventHandler; irq: LONGINT);

	Char *: PROCEDURE (c: CHAR);
	String *: PROCEDURE (CONST str: ARRAY OF CHAR);
	Int *: PROCEDURE (i: HUGEINT; w: LONGINT);
	Hex *: PROCEDURE (i: HUGEINT; w: LONGINT);
	Address *: PROCEDURE (a: ADDRESS);
	Set *: PROCEDURE (s: SET);
	Boolean *: PROCEDURE (b: BOOLEAN);
	Ln *: PROCEDURE;
	FlushDCacheRange *,
	InvalidateDCacheRange *: PROCEDURE (adr: ADDRESS; len: SIZE);
	
	GetTimeCounter-: PROCEDURE(): Time;
	
	cpuClockHz: LONGINT;

	PROCEDURE Enable * (sd: LONGINT): BOOLEAN;
	VAR
		key, value: ARRAY 32 OF CHAR;
	BEGIN
		key := "SdEnable";
		Strings.IntToStr(sd, value);
		Strings.Append(key, value);
		Machine.GetConfig(key, value);
		RETURN value = "1"
	END Enable;

	PROCEDURE HcClock * (sd: LONGINT): LONGINT;
	VAR
		clock, res: LONGINT;
	BEGIN
		clock := LONGINT(PsConfig.GetIoClockFrequency(PsConfig.IoSdio, res));
		ASSERT(res = 0);
		RETURN clock
	END HcClock;

	PROCEDURE GetLock * (VAR acq, rel: PROCEDURE {DELEGATE});
	VAR
		lock: Locks.Lock;
	BEGIN
		NEW(lock);
		acq := lock.Acquire;
		rel := lock.Release
	END GetLock;
	
	(** Convert microseconds to time counts *)
	PROCEDURE FromMicro*(us: Time): Time;
	BEGIN
		RETURN us * ENTIERH(0.5D0+LONGREAL(cpuClockHz)/2.0D6);
	END FromMicro;

	(** Convert time counts to microseconds *)
	PROCEDURE ToMicro*(time: Time): Time;
	BEGIN
		RETURN ENTIERH((0.5D0 + time) / (LONGREAL(cpuClockHz)) * 2.0D6)
	END ToMicro;

	(** Convert milliseconds to time counts *)
	PROCEDURE FromMilli*(ms: Time): Time;
	BEGIN
		RETURN ms * ENTIERH(0.5D0 + LONGREAL(cpuClockHz)/2.0D3);
	END FromMilli;

	(** Convert time counts to milliseconds *)
	PROCEDURE ToMilli*(time: Time): Time;
	BEGIN
		RETURN ENTIERH((0.5D0 + time) / (LONGREAL(cpuClockHz)) * 2.0D3)
	END ToMilli;

	PROCEDURE WaitMilli*(ms: Time);
	VAR t: Time;
	BEGIN
		t := GetTimeCounter() + FromMilli(ms);
		WHILE GetTimeCounter() <= t DO END;
	END WaitMilli;
	
	PROCEDURE WaitMicro*(us: Time);
	VAR t: Time;
	BEGIN
		t := GetTimeCounter() + FromMicro(us);
		WHILE GetTimeCounter() <= t DO END;
	END WaitMicro;
	
BEGIN
	InstallHandler := Objects.InstallHandler;
	Char := KernelLog.Char;
	String := KernelLog.String;
	Int := KernelLog.Int;
	Hex := KernelLog.Hex;
	Address := KernelLog.Address;
	Set := KernelLog.Set;
	Boolean := KernelLog.Boolean;
	Ln := KernelLog.Ln;
	FlushDCacheRange := Machine.FlushDCacheRange;
	InvalidateDCacheRange := Machine.InvalidateDCacheRange;
	cpuClockHz := BootConfig.GetIntValue("CpuClockHz");
	
	GetTimeCounter := Machine.GetTimer;
END SdEnvironment.2
