MODULE (*Dyn*)BootConfig; (** AUTHOR "Timothée Martiel"; PURPOSE "Boot configuration from memory area"; *)

IMPORT
	SYSTEM,
	Initializer(*,
	Commands*);

CONST
	ConfigSize = 4096;
	CR = 0DX;
	LF = 0AX;

VAR
	config: POINTER {UNSAFE,UNTRACED} TO ARRAY ConfigSize OF CHAR;
	size: LONGINT;

	PROCEDURE GetValue * (CONST key: ARRAY OF CHAR; VAR value: ARRAY OF CHAR);
	VAR
		i, len: LONGINT;
	BEGIN
		i := 0;
		len := 0;
		LOOP
			IF i = size THEN EXIT END;
			(* is that the key? *)
			IF MatchKey(config^, i, key) THEN
				REPEAT INC(i) UNTIL config[i] = '=';
				INC(i);
				WHILE (config[i + len] # CR) & (config[i + len] # LF) DO INC(len) END;
				ASSERT(len <= LEN(value), 7);
				SYSTEM.MOVE(ADDRESSOF(config[i]), ADDRESSOF(value[0]), len);
				EXIT
			ELSE
				REPEAT INC(i) UNTIL (i = size) OR (config[i] = LF);
				IF i = size THEN EXIT END;
				INC(i)
			END;
		END;
		value[len] := 0X;
	END GetValue;

	PROCEDURE GetIntValue * (CONST key: ARRAY OF CHAR): LONGINT;
	VAR
		str: ARRAY 128 OF CHAR;
	BEGIN
		GetValue(key, str);
		RETURN StrToInt(str)
	END GetIntValue;

	PROCEDURE GetBoolValue * (CONST key: ARRAY OF CHAR): BOOLEAN;
	VAR
		str: ARRAY 128 OF CHAR;
	BEGIN
		GetValue(key, str);
		RETURN StrToBool(str)
	END GetBoolValue;

	PROCEDURE Init *;
	BEGIN
		SYSTEM.MOVE(Initializer.configBase, 1FFFF000H, Initializer.configSize);
		Initializer.configBase := 1FFFF000H;
		config := Initializer.configBase;
		size := Initializer.configSize;
		IF size >= ConfigSize THEN size := ConfigSize-1; END;
		config[size] := CR;
	END Init;

	PROCEDURE StrToInt (CONST str: ARRAY OF CHAR): LONGINT;
	VAR
		i, value: LONGINT;
	BEGIN
		i := 0;
		value := 0;
		LOOP
			IF (i = LEN(str)) OR (str[i] = 0X) THEN RETURN value END;
			IF (str[i] > '9') OR (str[i] < '0') THEN RETURN 0 END;
			value := value * 10;
			INC(value, ORD(str[i]) - ORD('0'));
			INC(i)
		END
	END StrToInt;

	PROCEDURE StrToBool (CONST str: ARRAY OF CHAR): BOOLEAN;
	BEGIN
		IF str = '1' THEN RETURN TRUE END;
		RETURN FALSE
	END StrToBool;

	(** return TRUE if str1 from ofs1 until the first '=' (excluded) matches str2 *)
	PROCEDURE MatchKey (CONST str1: ARRAY OF CHAR; ofs1: LONGINT; CONST str2: ARRAY OF CHAR): BOOLEAN;
	VAR
		i: LONGINT;
	BEGIN
		i := 0;
		WHILE (str1[ofs1 + i] # '=') & (str2[i] # 0X) & (str1[ofs1 + i] = str2[i]) DO INC(i) END;
		RETURN (str1[ofs1 + i] = '=') & (str2[i] = 0X)
	END MatchKey;

(*	PROCEDURE Get * (context: Commands.Context);
	VAR
		key, val: ARRAY 128 OF CHAR;
	BEGIN
		IF ~context.arg.GetString(key) THEN RETURN END;
		context.out.String(key);
		context.out.String(": ");
		IF context.arg.GetString(val) THEN
			IF val = "int" THEN
				context.out.Int(GetIntValue(key), 0)
			ELSIF val = "bool" THEN
				IF GetBoolValue(key) THEN
					context.out.String("TRUE")
				ELSE
					context.out.String("FALSE")
				END
			ELSE
				GetValue(key, val);
				context.out.String("'");
				context.out.String(val);
				context.out.String("'");
			END
		ELSE
			GetValue(key, val);
			context.out.String("'");
			context.out.String(val);
			context.out.String("'");
		END;
		context.out.Ln
	END Get;

	PROCEDURE Print * (context: Commands.Context);
	VAR
		i: LONGINT;
	BEGIN
		FOR i := 0 TO size - 1 DO
			context.out.Char(config[i])
		END
	END Print;*)
(*BEGIN
	cfg := "CpuClockHz=666666666
UartInputClockHz=50000000
KernelOutputUart=1
PsRefClockHz=50000000
KernelOutputUart=1
CpuNb=2
UsbPhyRstGpio0=46
UsbPhyRstGpio1=-1
UsbEnable0=1
UsbEnable1=0
UsbViewportInit=1
SdClock0=50000000
SdClock1=50000000
SdEnable0=1
SdEnable1=0
CpuNb=2
DDRSize=536870912
ConfigSize=4096;
HeapSize=469762048
KernelLoadAdr=1048576
StackSize=262144
EnableCaching=1
EnableKernelWatchdog=1
EnableFreeLists=0
EnableReturnBlocks=0
TraceHeaps=0
TraceModules=0
TraceInterrupts=0
";
config := ADDRESSOF(cfg[0]);
size := Strings.Length(cfg)*)
END (*Dyn*)BootConfig.
