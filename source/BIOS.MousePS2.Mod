(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE MousePS2; (** AUTHOR "pjm"; PURPOSE "PS/2 mouse driver"; *)

(*
	Mouse protocol information from XFree in X11R6 distribution (Thomas Roell & David Dawes)
	PS/2 Aux port information from Linux (Johan Myreen et al.)
*)

IMPORT SYSTEM, Machine, Modules, Objects, Kernel, Inputs;

TYPE
	Aux = OBJECT
		VAR
			p, numb: SIGNED32;
			buf: ARRAY 4 OF SET;
			active: BOOLEAN;
			timer: Objects.Timer;

		PROCEDURE HandleInterrupt;
		VAR b: SET; m: Inputs.MouseMsg; ch: CHAR; s: SET;
		BEGIN {EXCLUSIVE}
			Machine.Portin8(64H, ch); (* check for valid data *)
			s := SET(ORD(ch));
			IF s * {0} = {} THEN INC(ignored); RETURN	END;
			Machine.Portin8(60H, ch);	(* read byte *)
			IF active THEN
				b := SYSTEM.VAL(SET, LONG(ORD(ch)));
				IF (p = 0) & (b * {6,7} # {}) THEN	(* skip package *)
					INC(errors)
				ELSE
					buf[p] := b; INC(p);
					IF p = numb THEN
						m.keys := {};
						IF 2 IN buf[0] THEN INCL(m.keys, 1) END;
						IF 1 IN buf[0] THEN INCL(m.keys, 2) END;
						IF 0 IN buf[0] THEN INCL(m.keys, 0) END;
						m.dx := SIGNED32(buf[1]);
						IF 4 IN buf[0] THEN DEC(m.dx, 256) END;
						m.dy := SIGNED32(buf[2]);
						IF 5 IN buf[0] THEN DEC(m.dy, 256) END;
						m.dz := SIGNED8(buf[3]);
						IF 6 IN buf[0] THEN DEC(m.dz, 256) END;
						p := 0; m.dy := -m.dy;
						Inputs.mouse.Handle(m)
					END
				END
			ELSE
				INC(ignored)
			END
		END HandleInterrupt;

		PROCEDURE HandleTimeout;
		BEGIN {EXCLUSIVE}
			active := TRUE
		END HandleTimeout;

		PROCEDURE &Init*(rate: SIGNED32);

			PROCEDURE SetRate(r: SIGNED32);
			BEGIN WriteAck(0F3X);  WriteAck(CHR(r))
			END SetRate;

		BEGIN
			active := FALSE; p := 0;
			PollAux;
			Machine.Portout8(64H, 0A8X);	(* enable aux *)
				(* enable MS Intellimouse 3rd button *)
			SetRate(200); SetRate(100); SetRate(80); SetRate(rate);
			WriteAck(0F2X);
			IF InAux() # 0X THEN numb := 4 ELSE numb := 3 END;	(* Ident *)
			WriteAck(0E8X);  WriteAck(3X);	(* 8 counts/mm *)
			WriteAck(0E7X);	(* 2:1 scale *)
			PollAux;
			Objects.InstallHandler(SELF.HandleInterrupt, Machine.IRQ0+12);
			WriteDev(0F4X);	(* enable aux device *)
			WriteCmd(47X);	(* controller interrupts on *)
			PollAux;
			NEW(timer); Objects.SetTimeout(timer, SELF.HandleTimeout, 250)	(* ignore bytes in first 1/4s *)
		END Init;

		PROCEDURE Remove;
		BEGIN {EXCLUSIVE}
			Objects.RemoveHandler(SELF.HandleInterrupt, Machine.IRQ0+12);
			Objects.CancelTimeout(timer)
		END Remove;

	END Aux;

VAR
	errors*, ignored*: SIGNED32;	(* diagnostic counters *)
	aux: Aux;

PROCEDURE PollAux;
VAR s: SET; i: SIGNED32; t: Kernel.MilliTimer; c: CHAR; 
BEGIN
	i := 10;	(* up to 0.2s! *)
	LOOP
		Machine.Portin8(64H, c);
		s := SET(ORD(c));
		IF (s * {0,1} = {}) OR (i = 0) THEN EXIT END;
		Machine.Portin8(64H, c);
		s := SET(ORD(c));
		IF s * {0,5} = {0,5} THEN Machine.Portin8(60H, c); s := SET(ORD(c)) END;	(* byte avail *)
		Kernel.SetTimer(t, 20);	(* 20ms *)
		REPEAT UNTIL Kernel.Expired(t);
		DEC(i)
	END
END PollAux;

PROCEDURE InAux(): CHAR;
VAR s: SET; t: Kernel.MilliTimer;ch: CHAR; i: SIGNED8;
BEGIN
	i := 10;	(* up to 0.2s! *)
	REPEAT
		Machine.Portin8(64H, ch);
		s := SET(ORD(ch));
		IF s * {0,5} = {0,5} THEN 	(* byte avail *)
			Machine.Portin8(60H, ch);
			RETURN ch
		END;
		Kernel.SetTimer(t, 20);
		REPEAT UNTIL Kernel.Expired(t);
		DEC(i);
	UNTIL i = 0;
	RETURN 0X
END InAux;
PROCEDURE WriteDev(b: CHAR);
BEGIN
	PollAux; Machine.Portout8(64H, 0D4X);	(* aux data coming *)
	PollAux; Machine.Portout8(60H, b)
END WriteDev;

PROCEDURE WriteAck(b: CHAR);
VAR s: SET; i: SIGNED32; t: Kernel.MilliTimer; c: CHAR;
BEGIN
	WriteDev(b); i := 10;	(* up to 0.2s! *)
	LOOP
		Machine.Portin8(64H, c);
		s := SET(ORD(c));
		IF (s * {0,5} = {0,5}) OR (i = 0) THEN EXIT END;
		Kernel.SetTimer(t, 20);	(* 20ms *)
		REPEAT UNTIL Kernel.Expired(t);
		DEC(i)
	END;
	IF i # 0 THEN Machine.Portin8(60H, c) END	(* byte avail *)
END WriteAck;

PROCEDURE WriteCmd(b: CHAR);
BEGIN
	PollAux; Machine.Portout8(64H, 60X);
	PollAux; Machine.Portout8(60H, b)
END WriteCmd;

PROCEDURE ConfigMouse;
VAR i: SIZE; rate: SIGNED32; s: ARRAY 16 OF CHAR;
BEGIN
	errors := 0; ignored := 0;
	Machine.GetConfig("MouseRate", s);
	i := 0; rate := Machine.StrToInt(i, s);
	IF (rate <= 0) OR (rate > 150) THEN rate := 100 END;
	NEW(aux, rate)
END ConfigMouse;

PROCEDURE Install*;
BEGIN
	IF aux = NIL THEN ConfigMouse END
END Install;

PROCEDURE Remove*;
BEGIN
	IF aux # NIL THEN aux.Remove(); aux := NIL END
END Remove;

BEGIN
	Modules.InstallTermHandler(Remove);
	aux := NIL; Install
END MousePS2.
