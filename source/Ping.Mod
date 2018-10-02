MODULE Ping; (** AUTHOR "mvt"; PURPOSE "Ping"; *)

IMPORT ICMP, DNS, IP, Network, Kernel, Objects, Commands, Modules, KernelLog;

CONST
	PingSize = 32; (* default packet data size in bytes *)
	MaxPingSize = 65535-20-8; (* maximum packet data size allowed *)
	PingHdrSize = 4; (* sequence number and identifier *)
	Timeout = 1000; (* default echo reply timeout in ms *)

VAR
	running: BOOLEAN; (* is an echo request (ping) currently running? *)
	timer: Objects.Timer;
	timeout: LONGINT;
	pingSize: LONGINT;
	ms: Kernel.MilliTimer;

(** Ping a host. Call: Ping.Ping host [pingSize] [timeout] ~ *)

PROCEDURE Ping*(context : Commands.Context);
VAR
	i: LONGINT;
	hostname: DNS.Name;
	fip: IP.Adr;
	res1, res2: WORD;
	data: ARRAY PingHdrSize+MaxPingSize OF CHAR;

BEGIN {EXCLUSIVE}
	AWAIT(~running);
	context.arg.SkipWhitespace; context.arg.String(hostname);
	context.arg.SkipWhitespace; context.arg.Int(pingSize, FALSE);
	context.arg.SkipWhitespace; context.arg.Int(timeout, FALSE);

	IF pingSize = 0 THEN pingSize := PingSize END;
	IF timeout = 0 THEN timeout := Timeout END;

	IF pingSize > MaxPingSize THEN
		pingSize := MaxPingSize;
	END;

	IF hostname # "" THEN
		context.out.String("Ping: Resolving host name: "); context.out.String(hostname); context.out.Ln;
		DNS.HostByName(hostname, fip, res1);
		IF res1 = DNS.Ok THEN
			(* Install Receivers for IPv6 and IPv6 *)
			ICMP.InstallReceiver(ICMP.TypeEchoReplyv4, GetReply, res1);
			ICMP.InstallReceiver(ICMP.TypeEchoReplyv6, GetReply, res2);

			IF (res1 = ICMP.Ok) & (res2 = ICMP.Ok) THEN
				FOR i := 0 TO PingHdrSize-1 DO
					data[i] := 0X; (* set sequence number and identifier to zero *)
				END;

				FOR i := 0 TO pingSize-1 DO
					data[PingHdrSize+i] := CHR(i MOD 256);
				END;
				context.out.String("Ping: Pinging "); IP.OutAdr(fip); context.out.String(" with ");
				context.out.Int(pingSize, 0); context.out.String(" bytes..."); context.out.Ln;
				IF fip.usedProtocol = IP.IPv4 THEN
					ICMP.Send(NIL, fip, data, 0, PingHdrSize+pingSize, ICMP.TypeEchoRequestv4, 0, IP.MaxTTL);
				ELSIF fip.usedProtocol = IP.IPv6 THEN
					ICMP.Send(NIL, fip, data, 0, PingHdrSize+pingSize, ICMP.TypeEchoRequestv6, 0, IP.MaxTTL);
				END;

				Objects.SetTimeout(timer, TimeoutHandler, timeout);
				Kernel.SetTimer(ms, 0);
				running := TRUE
			ELSE
				context.error.String("Ping: Couldn't install receiver in ICMP, probably reserved by another application."); context.error.Ln
			END;
		ELSE
			context.error.String("Ping: Couldn't resolve host name: "); context.error.String(hostname); context.error.Ln
		END;
	ELSE
		context.error.String("Ping: Parameter error: No hostname defined!"); context.error.Ln
	END;
END Ping;

PROCEDURE TimeoutHandler;
VAR res: WORD;
BEGIN {EXCLUSIVE}
	IF running THEN
		KernelLog.String("Ping: Timeout! No reply received within "); KernelLog.Int(timeout, 0);
		KernelLog.String(" ms."); KernelLog.Ln;
		running := FALSE;
		ICMP.RemoveReceiver(ICMP.TypeEchoReplyv4, res);
		ICMP.RemoveReceiver(ICMP.TypeEchoReplyv6, res);
	ELSE
		(* occurred during GetReply *)
	END;
END TimeoutHandler;

PROCEDURE GetReply(int: IP.Interface; type, code: LONGINT; fip, lip: IP.Adr; buffer: Network.Buffer);
VAR res: WORD;
BEGIN {EXCLUSIVE}
	IF running THEN
		KernelLog.String("Ping: Successful! Reply received within "); KernelLog.Int(Kernel.Elapsed(ms), 0);
		KernelLog.String(" ms."); KernelLog.Ln;
		running := FALSE;
		Objects.CancelTimeout(timer);
		ICMP.RemoveReceiver(ICMP.TypeEchoReplyv4, res);
		ICMP.RemoveReceiver(ICMP.TypeEchoReplyv6, res);
	ELSE
		(* timeout already occurred *)
	END;
	Network.ReturnBuffer(buffer)
END GetReply;

PROCEDURE Cleanup;
VAR res: WORD;
BEGIN {EXCLUSIVE}
	IF running THEN
		running := FALSE;
		Objects.CancelTimeout(timer);
		ICMP.RemoveReceiver(ICMP.TypeEchoReplyv4, res);
		ICMP.RemoveReceiver(ICMP.TypeEchoReplyv6, res);
	END
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
	NEW(timer)
END Ping.

(*
Usage: Ping.Ping host [pingSize] [timeout]

"pingSize" is the size of the ping packet data in bytes.
"timeout" is the echo reply timeout in ms.

Aos.Call Ping.Ping 127.0.0.1~
Aos.Call Ping.Ping 10.0.0.1 1024~
Aos.Call Ping.Ping 129.132.98.12~
Aos.Call Ping.Ping 129.132.250.220~
Aos.Call Ping.Ping www.ethz.ch 128 100~
System.Free Ping~
*)
