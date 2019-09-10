(**
	AUTHOR: "Felix Friedrich and Alexey Morozov";
	PURPOSE: "ActiveCells AXI-4 Stream input/output interface for Tiny Register Machine (TRM) implemented on an FPGA";
*)
MODULE Channels;

IMPORT
	SYSTEM;

CONST
	ValidFlag* = (*100H;*) 010H;
	ReadyFlag* = (*200H;*) 020H;

	(** Send data to an output port (blocking version) *)
	PROCEDURE Send*(portAddr: ADDRESS; x: SIGNED32);
	BEGIN
		REPEAT UNTIL SYSTEM.BIT(portAddr+ReadyFlag,0); (* wait until the sink is ready *)
		SYSTEM.PUT(portAddr,x);
	END Send;

	(** Send data to an output port (non-blocking version) *)
	PROCEDURE SendNonBlocking*(portAddr: ADDRESS; x: SIGNED32): BOOLEAN;
	BEGIN
		IF SYSTEM.BIT(portAddr+ReadyFlag,0) THEN
			SYSTEM.PUT(portAddr,x);
			RETURN TRUE;
		ELSE
			RETURN FALSE;
		END;
	END SendNonBlocking;

	(** Receive data from an input port (blocking version) *)
	PROCEDURE Receive*(portAddr: ADDRESS; VAR x: SIGNED32);
	BEGIN
		REPEAT UNTIL SYSTEM.BIT(portAddr+ValidFlag,0); (* wait until the source data is valid *)
		SYSTEM.GET(portAddr,x);
	END Receive;

	(** Receive data from an input port (non-blocking version) *)
	PROCEDURE ReceiveNonBlocking*(portAddr: ADDRESS; VAR x: SIGNED32): BOOLEAN;
	BEGIN
		IF SYSTEM.BIT(portAddr+ValidFlag,0) THEN
			SYSTEM.GET(portAddr,x);
			RETURN TRUE;
		ELSE
			RETURN FALSE;
		END;
	END ReceiveNonBlocking;

	(** Send a block of bytes to a port *)
	PROCEDURE SendBytes*(portAddr: ADDRESS; CONST x: ARRAY OF CHAR; offs, len: SIGNED32);
	BEGIN
		WHILE len > 0 DO
			Send(portAddr,ORD(x[offs]));
			INC(offs); DEC(len);
		END;
	END SendBytes;

	(** Receive a block of bytes from a port *)
	PROCEDURE ReceiveBytes*(portAddr: ADDRESS; VAR x: ARRAY OF CHAR; offs, len: SIGNED32);
	VAR v: SIGNED32;
	BEGIN
		WHILE len > 0 DO
			Receive(portAddr,v); x[offs] := CHR(v);
			INC(offs); DEC(len);
		END;
	END ReceiveBytes;

	(** Send a character to a port *)
	PROCEDURE SendChar*(portAddr: ADDRESS; ch: CHAR);
	BEGIN
		Send(portAddr,ORD(ch));
	END SendChar;

	(** Send a null terminated strings; the terminating null is not sent *)
	PROCEDURE SendString*(portAddr: ADDRESS; CONST str: ARRAY OF CHAR);
	VAR i: SIGNED32;
	BEGIN
		i := 0;
		WHILE (i < LEN(str)) & (str[i] # 0X) DO
			Send(portAddr,ORD(str[i]));
			INC(i);
		END;
	END SendString;

	(** Send an integer in decimal right-justified in a field of at least w characters  *)
	PROCEDURE SendInt*(portAddr: ADDRESS; x, w: SIGNED32);
	VAR
		i, x0, y: SIGNED32;
		str: ARRAY 12 OF CHAR;
	BEGIN
		IF x < 0 THEN
			IF x = MIN(SIGNED32) THEN
				DEC(w,11);
				WHILE w > 0 DO SendChar(portAddr,' ');  DEC(w); END;
				SendString(portAddr,"-2147483648");  RETURN;
			ELSE DEC(w);  x0 := -x;
			END
		ELSIF x = 0 THEN
			WHILE w > 1 DO SendChar(portAddr,' ');  DEC(w); END;
			SendChar(portAddr,'0'); RETURN;
		ELSE x0 := x;
		END;

		i := 0;
		WHILE x0 > 0 DO
			y := x0 DIV 10;
			str[i] := CHR(x0 - (y*10)+48); (*k := y*10; k := x0-k; k := k + 48; str[i] := CHR(k);*)
			x0 := y;
			INC(i);
		END;

		WHILE w > i DO SendChar(portAddr,' ');  DEC(w); END;
		IF x < 0 THEN SendChar(portAddr,'-') END;
		REPEAT DEC(i);  SendChar(portAddr,str[i]); UNTIL i = 0;
	END SendInt;

END Channels.
