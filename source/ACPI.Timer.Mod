(* Runtime support for high precision timer *)
(* Copyright (C) Florian Negele *)

MODULE Timer;

IMPORT ACPI, SYSTEM;

TYPE Counter* = SIGNED32;

VAR frequency: Counter;
VAR counter {UNTRACED}: POINTER {UNSAFE} TO RECORD value: SIGNED64 END;

PROCEDURE - GetInstructionTimer(): SIGNED64;
CODE
	RDTSC
END GetInstructionTimer;

PROCEDURE GetCounter- (): Counter;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	IF counter = NIL THEN RETURN  SHORT(GetInstructionTimer() DIV (1024*1024));  (* return millions of instructions *) END;
	ASSERT (counter # NIL); RETURN SHORT (counter.value);
END GetCounter;

PROCEDURE GetFrequency- (): Counter;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	IF counter = NIL THEN RETURN 1024 (* giga instructions as a rough guess *) END;
	RETURN frequency;
END GetFrequency;

PROCEDURE Initialize-;
CONST OverallEnable = 0;
VAR hpet {UNTRACED}: POINTER {UNSAFE} TO ACPI.HPET; address: ADDRESS;
VAR period {UNTRACED}: POINTER {UNSAFE} TO RECORD value: SIGNED32 END; configuration {UNTRACED}: POINTER {UNSAFE} TO RECORD value: SET END;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ACPI.Initialize;
	IF ACPI.rdsp = NIL THEN RETURN END;
	hpet := ACPI.GetTable (ACPI.HPETSignature);
	IF hpet = NIL THEN RETURN END;
	address := ACPI.Convert (hpet.baseAddress.addressLow);
	period := address + SIZE OF CHAR * 004H;
	counter := address + SIZE OF CHAR * 0F0H;
	configuration := address + SIZE OF CHAR * 010H;
	frequency := SHORT (1000000000000000 DIV period.value);
	INCL (configuration.value, OverallEnable);
END Initialize;

END Timer.
