MODULE TraceRoute; (** AUTHOR "mvt"; PURPOSE "TraceRoute"; *)

IMPORT ICMP, DNS, IP, Network, Kernel, Objects, Commands;

CONST
	PingSize = 32; (* default packet data size in bytes *)
	MaxPingSize = 65535-20-8; (* maximum packet data size allowed *)
	PingHdrSize = 4; (* sequence number and identifier *)
	Timeout = 1000; (* default echo reply timeout in ms *)
	DEBUG = FALSE;

VAR
	running: BOOLEAN; (* is traceroute currently running? *)
	timer: Objects.Timer;
	timeoutMS: SIGNED32; (* timeout in ms *)
	pingSize: SIGNED32; (* ping size in bytes *)
	TTL: SIGNED32; (* time-to-live for outgoing packets *)
	fip: IP.Adr; (* foreign IP address *)
	timeout: BOOLEAN; (* timeout occurred *)
	replyIP: IP.Adr; (* If not IP.NilAdr, a packet was received with this foreign IP address *)
	replyExceed: BOOLEAN; (* TRUE if packet is an "exceeded" packet, FALSE if it is an "echo reply" packet *)

(** Run TraceRoute. Call: TraceRoute.TraceRoute host [pingSize] [timeout] ~ *)

PROCEDURE TraceRoute*(context : Commands.Context);
VAR
	hostname: DNS.Name;
	milliTimer : Kernel.MilliTimer;
	res : INTEGER;
BEGIN
	BEGIN {EXCLUSIVE}
		AWAIT(~running);
		running := TRUE;
	END;
	context.arg.SkipWhitespace; context.arg.String(hostname);
	context.arg.SkipWhitespace; context.arg.Int(pingSize, FALSE);
	context.arg.SkipWhitespace; context.arg.Int(timeoutMS, FALSE);

	IF pingSize = 0 THEN pingSize := PingSize END;
	IF timeoutMS = 0 THEN timeoutMS := Timeout END;

	IF pingSize > MaxPingSize THEN
		pingSize := MaxPingSize;
	END;

	IF hostname # "" THEN
		context.out.String("TraceRoute: Resolving host name: "); context.out.String(hostname); context.out.Ln;
		DNS.HostByName(hostname, fip, res);
		IF res = DNS.Ok THEN
			ICMP.InstallReceiver(ICMP.TypeEchoReplyv4, GetReply, res);
			ICMP.InstallReceiver(ICMP.TypeEchoReplyv6, GetReply, res);
			IF res = ICMP.Ok THEN
				ICMP.InstallReceiver(ICMP.TypeTimeExceededv4, GetReply, res);
				ICMP.InstallReceiver(ICMP.TypeTimeExceededv6, GetReply, res);
			END;
			IF res = ICMP.Ok THEN
				context.out.String("TraceRoute: Starting traceroute for host "); IP.OutAdr(fip); context.out.String(" with ");
				context.out.Int(pingSize, 0); context.out.String(" bytes..."); context.out.Ln;
				TTL := 1;
				LOOP
					BEGIN {EXCLUSIVE}
						timeout := FALSE;
						replyIP := IP.NilAdr;
						Kernel.SetTimer(milliTimer, 0);
						SendEchoRequest();
						AWAIT(timeout OR (~IP.IsNilAdr(replyIP)));
					END;
					IF timeout THEN
						context.error.String("TraceRoute: ["); context.error.Int(TTL, 0); context.error.String("] Timeout! No reply received within ");
						context.error.Int(timeoutMS, 0); context.error.String("ms."); context.error.Ln;
						context.error.String("TraceRoute: Finished."); context.error.Ln;
						ICMP.RemoveReceiver(ICMP.TypeEchoReplyv4, res);
						ICMP.RemoveReceiver(ICMP.TypeEchoReplyv6, res);
						ICMP.RemoveReceiver(ICMP.TypeTimeExceededv4, res);
						ICMP.RemoveReceiver(ICMP.TypeTimeExceededv6, res);
						EXIT;
					ELSE
						Objects.CancelTimeout(timer);
						context.error.String("TraceRoute: ["); context.error.Int(TTL, 0); context.error.String("] ");
						context.error.Int(Kernel.Elapsed(milliTimer), 0); context.error.String("ms, ");
						DNS.HostByNumber(replyIP, hostname, res);
						IF res = DNS.Ok THEN
							context.error.String(hostname); context.error.String(" ["); IP.OutAdr(replyIP); context.error.String("]");
						ELSE
							IP.OutAdr(replyIP);
						END;
						context.error.Ln;
						IF replyExceed THEN
							INC(TTL);
							IF TTL > 255 THEN
								context.error.String("TraceRoute: TTL of 255 reached. Aborted."); context.error.Ln;
								EXIT;
							END;
						ELSE
							context.out.String("TraceRoute: Finished."); context.out.Ln;
							ICMP.RemoveReceiver(ICMP.TypeEchoReplyv4, res);
							ICMP.RemoveReceiver(ICMP.TypeEchoReplyv6, res);
							ICMP.RemoveReceiver(ICMP.TypeTimeExceededv4, res);
							ICMP.RemoveReceiver(ICMP.TypeTimeExceededv6, res);
							EXIT;
						END;
					END;
				END;
			ELSE
				context.error.String("TraceRoute: Couldn't install receiver in ICMP, probably reserved by another application!"); context.error.Ln
			END;
		ELSE
			context.error.String("TraceRoute: Couldn't resolve host name: "); context.error.String(hostname); context.error.Ln
		END;
	ELSE
		context.error.String("TraceRoute: Parameter error: No hostname defined!"); context.error.Ln
	END;
	BEGIN {EXCLUSIVE}
		ASSERT(running);
		running := FALSE;
	END;
END TraceRoute;

PROCEDURE SendEchoRequest;
VAR
	i: SIGNED32;
	data: ARRAY PingHdrSize+MaxPingSize OF CHAR;
BEGIN
	FOR i := 0 TO PingHdrSize-1 DO
		data[i] := 0X; (* set sequence number and identifier to zero *)
	END;
	FOR i := 0 TO pingSize-1 DO
		data[PingHdrSize+i] := CHR(i MOD 256);
	END;
	IF fip.usedProtocol = IP.IPv4 THEN
		ICMP.Send(NIL, fip, data, 0, PingHdrSize+pingSize, ICMP.TypeEchoRequestv4, 0, TTL);
	ELSIF fip.usedProtocol = IP.IPv6 THEN
		ICMP.Send(NIL, fip, data, 0, PingHdrSize + pingSize, ICMP.TypeEchoRequestv6, 0, TTL);
	ELSE
		IF DEBUG THEN
			ASSERT(TRUE);
		END;
	END;
	Objects.SetTimeout(timer, TimeoutHandler, timeoutMS);
END SendEchoRequest;

PROCEDURE TimeoutHandler;
BEGIN {EXCLUSIVE}
	timeout := TRUE;
END TimeoutHandler;

PROCEDURE GetReply(int: IP.Interface; type, code: SIGNED32; fip, lip: IP.Adr; buffer: Network.Buffer);
BEGIN {EXCLUSIVE}
	Objects.CancelTimeout(timer);
	IF (type = ICMP.TypeTimeExceededv4) OR (type = ICMP.TypeTimeExceededv6) THEN
		replyIP := fip;
		replyExceed := TRUE;
	ELSIF (type = ICMP.TypeEchoReplyv4) OR (type = ICMP.TypeEchoReplyv6) THEN
		replyIP := fip;
		replyExceed := FALSE;
	ELSE
		(* ignore *)
	END;
END GetReply;

BEGIN
	NEW(timer)
END TraceRoute.

(*
Usage: TraceRoute.TraceRoute host [pingSize] [timeout]

"pingSize" is the size of the ping packet data in bytes, used by traceroute.
"timeout" is the echo reply timeout in ms.

Aos.Call TraceRoute.TraceRoute 127.0.0.1~
Aos.Call TraceRoute.TraceRoute 10.0.0.1 1024~
Aos.Call TraceRoute.TraceRoute www.google.ch 128 500~
System.Free TraceRoute~
*)
