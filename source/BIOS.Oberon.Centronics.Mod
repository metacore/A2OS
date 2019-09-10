(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE Centronics IN Oberon;	(** non-portable *)	(* pjm 07.08.95 *)

(* Aos version *)

IMPORT SYSTEM, Kernel IN A2, Machine IN A2;

CONST
	LPT1* = 0;
	LPT2* = 1;
	LPT3* = 2;

	Timeout = 0;	(* in seconds *)

VAR
	adr: ARRAY 3 OF SIGNED16;
	num: SIGNED16;

PROCEDURE Halt(msg: ARRAY OF CHAR);
VAR error: ARRAY 32 OF CHAR;
BEGIN
	COPY(msg, error);
	HALT(99)
END Halt;

PROCEDURE Wait;
VAR t: Kernel.MilliTimer;
BEGIN
	Kernel.SetTimer(t, 1);	(* assume one GetTimer tick > 50us *)
	REPEAT UNTIL Kernel.Expired(t)
END Wait;

(** Start - Open parallel port. *)

PROCEDURE Start*(port: SIGNED16);
BEGIN
	IF (port < 0) OR (port >= num) THEN Halt("Invalid parallel port") END
END Start;

(** Reset - Reset parallel port. *)

PROCEDURE Reset*(port: SIGNED16);
VAR p: SIGNED16;
BEGIN
	IF port >= num THEN HALT(99) END;
	p := adr[port];
	INC(p, 2);  Machine.Portout8(p, 8X);
	Wait;  Machine.Portout8(p, 0CX)
END Reset;

(** Stop - Close parallel port. *)

PROCEDURE Stop*(port: SIGNED16);
(* nop in current implementation *)
END Stop;

(** Send - Send byte to parallel port, waiting until it is ready. *)

PROCEDURE Send*(port: SIGNED16; x: CHAR);
VAR p: SIGNED16;  s: SET;  t: Kernel.MilliTimer;
BEGIN
	IF port >= num THEN Halt("Invalid parallel port") END;
	p := adr[port]+1;
	IF Timeout = 0 THEN
		REPEAT
			Machine.Portin8(p, SYSTEM.VAL(CHAR, s));
			Machine.Portin8(p, SYSTEM.VAL(CHAR, s));
		UNTIL 7 IN s
	ELSE
		Kernel.SetTimer(t, Timeout*1000);
		REPEAT
			Machine.Portin8(p, SYSTEM.VAL(CHAR, s));
			Machine.Portin8(p, SYSTEM.VAL(CHAR, s));
			IF 5 IN s THEN	(* out of paper *)
				Machine.Portin8(p, SYSTEM.VAL(CHAR, s));
				IF 5 IN s THEN	(* still out of paper *)
					Halt("Out of paper")
				END
			END;
			IF ~(3 IN s) THEN	(* error *)
				Halt("Printer error")
			END
		UNTIL (7 IN s) OR Kernel.Expired(t)
	END;
	IF 7 IN s THEN
		p := adr[port];  Machine.Portout8(p, x);
		INC(p, 2);  Machine.Portout8(p, 0DX);
		Machine.Portout8(p, 0DX);  Machine.Portout8(p, 0CX)
	ELSE
		Halt("Printer timeout")
	END
END Send;

(** SendPoll - Send byte to parallel port.  done indicates success or failure. *)

PROCEDURE SendPoll*(port: SIGNED16;  x: CHAR;  VAR done: BOOLEAN);
VAR p: SIGNED16;  s: SET;
BEGIN
	IF port >= num THEN Halt("Invalid parallel port") END;
	p := adr[port]+1;
	Machine.Portin8(p, SYSTEM.VAL(CHAR, s));
	Machine.Portin8(p, SYSTEM.VAL(CHAR, s));
	IF 7 IN s THEN
		p := adr[port];  Machine.Portout8(p, x);
		INC(p, 2);  Machine.Portout8(p, 0DX);
		Machine.Portout8(p, 0DX);  Machine.Portout8(p, 0CX);
		done := TRUE
	ELSE
		done := FALSE
	END
END SendPoll;

(** Available - Returns number of bytes available for reading (implementation optional). *)

PROCEDURE Available*(port: SIGNED16): SIGNED32;
BEGIN
	Halt("Not implemented");
	RETURN 0
END Available;

(** Receive - Read a byte from the parallel port (implementation optional). *)

PROCEDURE Receive*(port: SIGNED16; VAR x: CHAR);
BEGIN
	Halt("Not implemented")
END Receive;

PROCEDURE Detected(adr: SIGNED16): BOOLEAN;
VAR p: SIGNED16; ch: CHAR;
BEGIN
	p := adr+2;  Machine.Portout8(p, 0CX);
	p := adr;  Machine.Portout8(p, 55X);
	Wait;  Machine.Portin8(p, ch);
	IF ch = 55X THEN
		Machine.Portout8(p, 0AAX);
		Wait;  Machine.Portin8(p, ch);
		IF ch = 0AAX THEN RETURN TRUE END
	END;
	RETURN FALSE
END Detected;

PROCEDURE Init;
VAR i: SIGNED8;  p: SIGNED16;
BEGIN
	num := 0;
	FOR i := 0 TO 2 DO
		CASE i OF
			0: p := 3BCH
			|1: p := 378H
			|2: p := 278H
		END;
		IF Detected(p) THEN adr[num] := p;  INC(num) END
	END
END Init;

BEGIN
	Init
END Centronics.
