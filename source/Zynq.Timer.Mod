(* Runtime support for high precision timer *)
(* Copyright (C) Florian Negele *)

MODULE Timer;

IMPORT CPU;

TYPE Counter* = LONGINT;

PROCEDURE GetCounter- (): Counter;
BEGIN {UNCOOPERATIVE, UNCHECKED} RETURN CPU.ReadWord (CPU.Global_Timer_Counter_Register0);
END GetCounter;

PROCEDURE GetFrequency- (): Counter;
BEGIN {UNCOOPERATIVE, UNCHECKED} RETURN 400000000;
END GetFrequency;

END Timer.
