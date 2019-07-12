(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE TestServer; (** AUTHOR "pjm"; PURPOSE "TCP test server (echo, discard, chargen, daytime)"; *)

(* TCP Echo (RFC 862), Discard (RFC 863), Daytime (RFC 867) and Chargen (RFC 864) services for Aos. *)

IMPORT Modules, KernelLog, TCP, TCPServices, Streams, Clock;

CONST
	EchoPort = 7;
	EchoBufSize = 4096;

	DiscardPort = 9;
	DiscardBufSize = 4096;

	ChargenPort = 19;
	ChargenFirstChar = 32; ChargenNumChars = 95;
	ChargenLineLength = 72; ChargenLineSize = 74;
	CharGenBufSize = ChargenLineSize * ChargenNumChars;

	DayTimePort = 13;

	Ok = TCP.Ok;

	Trace = TRUE;

TYPE
	DiscardAgent = OBJECT (TCPServices.Agent)
		VAR len: SIZE; res: WORD; buf: ARRAY DiscardBufSize OF CHAR;

	BEGIN {ACTIVE}
		REPEAT
			client.Receive(buf, 0, LEN(buf), LEN(buf), len, res)
		UNTIL res # Ok;
		IF Trace THEN
			KernelLog.Enter; KernelLog.String("Discard result "); KernelLog.Int(res, 1); KernelLog.Exit
		END;
		Terminate
	END DiscardAgent;

TYPE
	EchoAgent = OBJECT (TCPServices.Agent)
		VAR len: SIZE; res: WORD; buf: ARRAY EchoBufSize OF CHAR;

	BEGIN {ACTIVE}
		LOOP
			client.Receive(buf, 0, LEN(buf), 1, len, res);
			IF res # Ok THEN EXIT END;
			client.Send(buf, 0, len, FALSE, res);
			IF res # Ok THEN EXIT END
		END;
		IF Trace THEN
			KernelLog.Enter; KernelLog.String("Echo result "); KernelLog.Int(res, 1); KernelLog.Exit
		END;
		Terminate
	END EchoAgent;

TYPE
	ChargenAgent = OBJECT (TCPServices.Agent)
		VAR res: WORD;

	BEGIN {ACTIVE}
		LOOP
			client.Send(chargenbuf^, 0, CharGenBufSize, FALSE, res);
			IF res # Ok THEN EXIT END
		END;
		IF Trace THEN
			KernelLog.Enter; KernelLog.String("Chargen result "); KernelLog.Int(res, 1); KernelLog.Exit
		END;
		Terminate
	END ChargenAgent;

TYPE
	DayTimeAgent = OBJECT (TCPServices.Agent)
		VAR time, date: LONGINT; w: Streams.Writer;

	BEGIN {ACTIVE}
		Streams.OpenWriter(w, client.Send);
		Clock.Get(time, date);
		w.Date822(time, date, Clock.tz);
		w.Ln;
		w.Update;
		Terminate
	END DayTimeAgent;

VAR
	discard, echo, chargen, daytime: TCPServices.Service;
	chargenbuf: POINTER TO ARRAY CharGenBufSize OF CHAR;

PROCEDURE InitChargenBuf;
VAR i, j, k: LONGINT;
BEGIN
	k := 0; NEW(chargenbuf);
	FOR i := 1 TO ChargenNumChars DO
		FOR j := 0 TO ChargenLineLength-1 DO
			chargenbuf[k] := CHR(ChargenFirstChar + (i+j) MOD ChargenNumChars); INC(k)
		END;
		chargenbuf[k] := 0DX; chargenbuf[k+1] := 0AX; INC(k, 2)
	END;
	ASSERT(k = CharGenBufSize)
END InitChargenBuf;

PROCEDURE Open*;
VAR res : WORD;
BEGIN
	NEW(discard, DiscardPort, NewDiscardAgent, res);
	NEW(echo, EchoPort, NewEchoAgent, res);
	NEW(chargen, ChargenPort, NewChargenAgent, res);
	NEW(daytime, DayTimePort, NewDayTimeAgent, res);
END Open;

PROCEDURE Close*;
BEGIN
	discard.Stop; discard := NIL;
	echo.Stop; echo := NIL;
	chargen.Stop; chargen := NIL;
	daytime.Stop; daytime := NIL;
END Close;

PROCEDURE NewDiscardAgent(c: TCP.Connection; s: TCPServices.Service): TCPServices.Agent;
VAR a: DiscardAgent;
BEGIN
	NEW(a, c, s); RETURN a
END NewDiscardAgent;

PROCEDURE NewEchoAgent(c: TCP.Connection; s: TCPServices.Service): TCPServices.Agent;
VAR a: EchoAgent;
BEGIN
	NEW(a, c, s); RETURN a
END NewEchoAgent;

PROCEDURE NewChargenAgent(c: TCP.Connection; s: TCPServices.Service): TCPServices.Agent;
VAR a: ChargenAgent;
BEGIN
	NEW(a, c, s); RETURN a
END NewChargenAgent;

PROCEDURE NewDayTimeAgent(c: TCP.Connection; s: TCPServices.Service): TCPServices.Agent;
VAR a: DayTimeAgent;
BEGIN
	NEW(a, c, s); RETURN a
END NewDayTimeAgent;

PROCEDURE Cleanup;
BEGIN
	Close;
END Cleanup;

BEGIN
	InitChargenBuf;
	discard := NIL; echo := NIL; chargen := NIL; daytime := NIL;
	Modules.InstallTermHandler(Cleanup)	(* there is still a race with System.Free *)
END TestServer.

System.Free TestServer ~

System.OpenKernelLog

Aos.Call TestServer.Open
Aos.Call TestServer.Close
