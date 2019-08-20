(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE DNS; (** AUTHOR "pjm, mvt"; PURPOSE "DNS client"; *)

(* Portions based on NetDNS.Mod by mg et al. *)

IMPORT KernelLog, Machine, Kernel, Network, IP, UDP;

CONST
	(** Error codes *)
	Ok* = 0;
	NotFound* = 3601;
	BadName* = 3602;
	MaxNofServer* = 10; (* max. number registered of DNS servers *)

	UDPTimeout = 1000; (* time per server query in ms *)
	Tries = 5; (* number of tries per server *)

	BadNameTimeout = 30; (* how many seconds to cache a bad name *)

	ArpaDomain = "IN-ADDR.ARPA";

	TypeA = 1;
	TypeAAAA = 28;
	TypeMX = 15;
	TypePTR = 12;
	TypeIN = 1;
	TypeRD = 100H;

	DNSPort = 53;

	Trace = FALSE;

TYPE
	Name* = ARRAY 128 OF CHAR; (* domain or host name type *)

	Cache = POINTER TO RECORD
		next: Cache;
		name, domain: Name;
		adr: IP.Adr;
		expire: LONGINT;
	END;

TYPE
	(* Internal server list - updated before each query *)

	ServerList = OBJECT
		VAR
			server: ARRAY MaxNofServer OF IP.Adr;
			currentServer, serverCount: LONGINT;

		PROCEDURE &Constr*;
		BEGIN
			currentServer := 0;
			serverCount := 0;
		END Constr;

		(* Update internal server list. Return number of servers. *)

		PROCEDURE Update(): LONGINT;
		BEGIN {EXCLUSIVE}
			serverCount := 0;
			IP.Enumerate(InterfaceHandler);
			IF currentServer >= serverCount THEN
				currentServer := 0;
			END;
			RETURN serverCount;
		END Update;

		(* Get current server. *)

		PROCEDURE GetServer(): IP.Adr;
		BEGIN {EXCLUSIVE}
			IF serverCount > 0 THEN
				RETURN server[currentServer];
			ELSE
				RETURN IP.NilAdr;
			END;
		END GetServer;

		(* Report current server to be bad. *)

		PROCEDURE ReportBadServer;
		BEGIN {EXCLUSIVE}
			IF serverCount > 0 THEN
				IF Trace THEN
					KernelLog.Enter; KernelLog.String("DNS: Server "); IP.OutAdr(server[currentServer]);
					KernelLog.String(" doesn't work. Switching to next..."); KernelLog.Ln; KernelLog.Exit;
				END;
				currentServer := (currentServer + 1) MOD serverCount;
			END;
		END ReportBadServer;

		(* Handle a call from IP.Enumerate() - update internal DNS server list. *)

		PROCEDURE InterfaceHandler(int: IP.Interface);
		VAR i: LONGINT;
		BEGIN
			IF int.dev.Linked() # Network.LinkNotLinked THEN
				i := 0;
				WHILE i < int.DNScount DO
					server[serverCount] := int.DNS[i];
					INC(serverCount);
					INC(i);
				END;
			ELSE
				(* device currently not linked to network *)
			END;
		END InterfaceHandler;

	END ServerList;

VAR
	(** Local domain name *)
	domain*: Name;

	id: LONGINT;
	cache: Cache;
	lastCleanup: LONGINT;

	serverlist: ServerList;

	(* Statistic variables *)
	NDNSReceived-, NDNSSent-, NDNSMismatchID-, NDNSError-: LONGINT;

PROCEDURE CacheCleanup;
VAR c, p: Cache; now: LONGINT;
BEGIN {EXCLUSIVE}
	now := Kernel.GetTicks();
	IF now - lastCleanup > Kernel.second THEN
		lastCleanup := now;
		p := cache; c := cache.next;
		WHILE c # NIL DO
			IF c.expire - now < 0 THEN
				IF Trace THEN
					KernelLog.String(" ("); KernelLog.String(c.name); KernelLog.String(" expired)")
				END;
				p.next := c.next; c := c.next
			ELSE
				p := c; c := c.next
			END
		END
	END
END CacheCleanup;

PROCEDURE CacheAdd(name: ARRAY OF CHAR; adr: IP.Adr; domain: ARRAY OF CHAR; timeout: LONGINT);
VAR c: Cache; expire: LONGINT;
BEGIN {EXCLUSIVE}
	IF timeout > MAX(LONGINT) DIV Kernel.second THEN timeout := MAX(LONGINT)
	ELSE timeout := timeout * Kernel.second
	END;
	expire := Kernel.GetTicks() + timeout; c := cache.next;
	WHILE (c # NIL) & ((name # c.name) OR (~IP.AdrsEqual(adr, c.adr))) DO c := c.next END;
	IF c = NIL THEN
		IF Trace THEN KernelLog.String(" added "); KernelLog.Int(timeout, 1) END;
		NEW(c); COPY(name, c.name); COPY(domain, c.domain); c.adr := adr;
		c.expire := expire; c.next := cache.next; cache.next := c
	ELSE
		IF expire - c.expire > 0 THEN
			IF Trace THEN KernelLog.String(" refreshed "); KernelLog.Int(timeout, 1) END;
			c.expire := expire; COPY(name, c.name); COPY(domain, c.domain); c.adr := adr
		END
	END
END CacheAdd;

PROCEDURE CacheFindDomain(domain: ARRAY OF CHAR): Cache;
VAR c: Cache;
BEGIN
	CacheCleanup;
	c := cache.next;
	WHILE (c # NIL) & (domain # c.domain) DO c := c.next END;
	IF Trace THEN
		IF c = NIL THEN KernelLog.String(" not") END;
		KernelLog.String(" in cache");
		IF c # NIL THEN KernelLog.Char(" "); KernelLog.Int((c.expire - Kernel.GetTicks()) DIV Kernel.second, 1) END
	END;
	RETURN c
END CacheFindDomain;

PROCEDURE CacheFindName(name: ARRAY OF CHAR): Cache;
VAR c: Cache;
BEGIN
	CacheCleanup;
	c := cache.next;
	WHILE (c # NIL) & (name # c.name) DO c := c.next END;
	IF Trace THEN
		IF c = NIL THEN KernelLog.String(" not") END;
		KernelLog.String(" in cache");
		IF c # NIL THEN KernelLog.Char(" "); KernelLog.Int((c.expire - Kernel.GetTicks()) DIV Kernel.second, 1) END
	END;
	RETURN c
END CacheFindName;

PROCEDURE CacheFindAdr(adr: IP.Adr): Cache;
VAR c: Cache;
BEGIN
	CacheCleanup;
	c := cache.next;
	WHILE (c # NIL) & (~IP.AdrsEqual(adr, c.adr)) DO c := c.next END;
	IF Trace THEN
		IF c = NIL THEN KernelLog.String(" not") END;
		KernelLog.String(" in cache");
		IF c # NIL THEN KernelLog.Char(" "); KernelLog.Int((c.expire - Kernel.GetTicks()) DIV Kernel.second, 1) END
	END;
	RETURN c
END CacheFindAdr;

PROCEDURE AppW(VAR k: LONGINT; VAR buf: ARRAY OF CHAR; n: LONGINT);
BEGIN
	buf[k] := CHR(n DIV 100H MOD 100H); buf[k+1] := CHR(n MOD 100H); INC(k, 2)
END AppW;

PROCEDURE QSect(VAR k: LONGINT; VAR buf, name: ARRAY OF CHAR; type, class: LONGINT);
VAR i, j: LONGINT;
BEGIN
	i := 0; j := k; INC(k);
	WHILE name[i] # 0X DO
		IF name[i] = "." THEN buf[j] := CHR(k-j-1); j := k	(* fixup len *)
		ELSE buf[k] := name[i]
		END;
		INC(k); INC(i)
	END;
	buf[j] := CHR(k-j-1); buf[k] := 0X; INC(k);
	AppW(k, buf, type); AppW(k, buf, class)
END QSect;

PROCEDURE PickW(VAR k: LONGINT; VAR buf: ARRAY OF CHAR; VAR n: LONGINT);
BEGIN
	n := ASH(ORD(buf[k]), 8) + ORD(buf[k+1]); INC(k, 2)
END PickW;

PROCEDURE Lower(VAR s: ARRAY OF CHAR);
VAR i: LONGINT;
BEGIN
	i := 0;
	WHILE s[i] # 0X DO
		IF (s[i] >= "A") & (s[i] <= "Z") THEN s[i] := CHR(ORD(s[i])+32) END;
		INC(i)
	END
END Lower;

PROCEDURE GetName(VAR k, i: LONGINT; VAR buf, name: ARRAY OF CHAR);
VAR len, k0: LONGINT;
BEGIN
	len := ORD(buf[k]); INC(k);
	WHILE len > 0 DO
		IF len >= 0C0H THEN
			k0 := 100H*(len-0C0H)+ORD(buf[k]); INC(k);
			GetName(k0, i, buf, name); name[i] := 0X; RETURN
		ELSE
			WHILE len > 0 DO name[i] := buf[k]; INC(i); INC(k); DEC(len) END
		END;
		len := ORD(buf[k]); INC(k);
		IF len > 0 THEN name[i] := "."; INC(i) END
	END;
	name[i] := 0X; Lower(name)
END GetName;

PROCEDURE Header(VAR k: LONGINT; VAR buf: ARRAY OF CHAR; id, flags, qd, an, ns, ar: LONGINT);
BEGIN
	AppW(k, buf, id); AppW(k, buf, flags); AppW(k, buf, qd);
	AppW(k, buf, an); AppW(k, buf, ns); AppW(k, buf, ar)
END Header;

PROCEDURE Domain(VAR name: ARRAY OF CHAR; localdom: ARRAY OF CHAR; force: BOOLEAN);
VAR i, j: LONGINT;
BEGIN
	i := 0; j := 0;
	WHILE name[i] # 0X DO
		IF name[i] = "." THEN j := i END;
		INC(i)
	END;
	IF force OR (j = 0) THEN
		j := 0; name[i] := "."; INC(i); (* append domain *)
		WHILE localdom[j] # 0X DO name[i] := localdom[j]; INC(i); INC(j) END;
		name[i] := 0X
	END;
	i := 0; j := 0;	(* remove extraneous dots *)
	WHILE name[i] = "." DO INC(i) END;
	WHILE name[i] # 0X DO
		name[j] := name[i]; INC(i); INC(j);
		IF name[i-1] = "." THEN
			WHILE name[i] = "." DO INC(i) END;
			IF name[i] = 0X THEN DEC(j) END
		END
	END;
	name[j] := 0X
END Domain;

PROCEDURE RetrieveInfo(qtype: LONGINT; VAR adr: IP.Adr; VAR buf, hname: ARRAY OF CHAR; VAR len: SIZE; VAR timeout: LONGINT; VAR res: WORD);
VAR
	name0: Name;
	adr0: IP.Adr;
	c, i, k, l, id0, flags, qd, an, ns, ar, type, class, ttl1, ttl0, ttl: LONGINT;

BEGIN
	k := 0; timeout := 0; res := NotFound; hname[0] := 0X;
	PickW(k, buf, id0);
	IF id0 = id THEN
		PickW(k, buf, flags); PickW(k, buf, qd); PickW(k, buf, an); PickW(k, buf, ns); PickW(k, buf, ar);
		IF flags MOD 10H = 0 THEN
			IF Trace THEN
				KernelLog.String(" qd="); KernelLog.Int(qd, 1);
				KernelLog.String(" an="); KernelLog.Int(an, 1);
				KernelLog.String(" ns="); KernelLog.Int(ns, 1);
				KernelLog.String(" ar="); KernelLog.Int(ar, 1)
			END;
			WHILE (qd > 0) & (k < len) DO
				i := 0; GetName(k, i, buf, name0); PickW(k, buf, type); PickW(k, buf, class);
				IF Trace THEN
					KernelLog.String(" name="); KernelLog.String(name0);
					KernelLog.String(" type="); KernelLog.Int(type, 1);
					KernelLog.String(" class="); KernelLog.Int(class, 1)
				END;
				DEC(qd)
			END;
			WHILE (an > 0) & (k < len) DO
				i := 0; GetName(k, i, buf, name0); PickW(k, buf, type); PickW(k, buf, class);
				PickW(k, buf, ttl1); PickW(k, buf, ttl0); PickW(k, buf, l);
				ttl := ttl1*10000H + ttl0;
				IF Trace THEN
					KernelLog.String(" name="); KernelLog.String(name0);
					KernelLog.String(" type="); KernelLog.Int(type, 1);
					KernelLog.String(" class="); KernelLog.Int(class, 1);
					KernelLog.String(" timeout="); KernelLog.Int(ttl, 1);
					KernelLog.String(" len="); KernelLog.Int(l, 1)
				END;
				IF type = qtype THEN
					CASE type OF
						TypeA:
							adr0.ipv4Adr := Network.Get4(buf, k); (* get IPv4 address *)
							adr0.usedProtocol := IP.IPv4;
							IF IP.IsNilAdr(adr) THEN adr := adr0; timeout := ttl; res := Ok END;
							INC(k, 4)
						|TypeAAAA:
							adr0.usedProtocol := IP.IPv6;
							FOR c := 0 TO 15 DO
								adr0.ipv6Adr[c] := buf[k+c];
							END;
							IF IP.IsNilAdr(adr) THEN adr := adr0; timeout := ttl; res := Ok END;
							INC(k,16);
						|TypePTR:
							IF hname[0] = 0X THEN
								i := 0; GetName(k, i, buf, hname); timeout := ttl; res := Ok
							ELSE
								INC(k, l);
							END;
						| TypeMX:
							IF hname[0] = 0X THEN
								PickW(k, buf, i); (* preference, not used yet *)
								i := 0; GetName(k, i, buf, hname); timeout := ttl; res := Ok
							ELSE
								INC(k, l);
							END;
					END
				ELSE
					INC(k, l)
				END;
				DEC(an)
			END
		ELSIF flags MOD 10H = 3 THEN	(* name error *)
			res := BadName; timeout := BadNameTimeout
		ELSE
			INC(NDNSError)
		END
	ELSE
		INC(NDNSMismatchID);
		IF Trace THEN
			KernelLog.String(" ID mismatch! Sent ID: "); KernelLog.Int(id, 0);
			KernelLog.String(" / Received ID: "); KernelLog.Int(id0, 0); KernelLog.Ln;
		END;
	END
END RetrieveInfo;

PROCEDURE SendQuery(pcb: UDP.Socket; server: IP.Adr; name: ARRAY OF CHAR; type: LONGINT; VAR buf: ARRAY OF CHAR; VAR res: WORD);
VAR len: LONGINT;
BEGIN
	len := 0; res := 0;
	Header(len, buf, id, 0 + TypeRD, 1, 0, 0, 0);
	QSect(len, buf, name, type, TypeIN);
	pcb.Send(server, DNSPort, buf, 0, len, res);
	INC(NDNSSent);
END SendQuery;

PROCEDURE ReceiveReply(pcb: UDP.Socket; VAR buf: ARRAY OF CHAR; VAR len: SIZE; VAR res: WORD);
VAR radr: IP.Adr; rport: LONGINT;
BEGIN
	REPEAT
		pcb.Receive(buf, 0, LEN(buf), UDPTimeout, radr, rport, len, res)
	UNTIL (rport = DNSPort) & (len > 0) OR (res # Ok);
	IF res = Ok THEN INC(NDNSReceived) ELSE len := 0 END
END ReceiveReply;

PROCEDURE QueryDNS(type: LONGINT; VAR buf, qname, hname: ARRAY OF CHAR; VAR adr: IP.Adr; VAR timeout: LONGINT; VAR res: WORD);
VAR
	j, k, serverCount: LONGINT;
	len: SIZE;
	pcb: UDP.Socket;
BEGIN
	serverCount := serverlist.Update();

	j := 0; res := NotFound;
	WHILE (res # Ok) & (j < serverCount) DO
		k := 0; Machine.AtomicInc(id);
		LOOP
			NEW(pcb, UDP.NilPort, res);
			IF res # UDP.Ok THEN
				RETURN;
			END;
			SendQuery(pcb, serverlist.GetServer(), qname, type, buf, res);
			IF res # Ok THEN
				pcb.Close();
				EXIT;
			END;	(* can not reach this server *)
			REPEAT	(* read replies *)
				ReceiveReply(pcb, buf, len, res);
				IF (res = Ok) & (len > 0) THEN
					RetrieveInfo(type, adr, buf, hname, len, timeout, res);
					IF (res = Ok) OR (res = BadName) THEN
						pcb.Close();
						RETURN;
					END;
				END
			UNTIL res # Ok;
			pcb.Close();
			INC(k);
			IF k = Tries THEN EXIT END;	(* maximum tries per server *)
			IF Trace THEN KernelLog.String(" retry") END
		END;
		IF res # Ok THEN
			serverlist.ReportBadServer();
		END;
		INC(j)
	END;
END QueryDNS;

(** Find the host responsible for mail exchange of the specified domain. *)

PROCEDURE MailHostByDomain*(domain: ARRAY OF CHAR; VAR hostname: ARRAY OF CHAR; VAR res: WORD);
VAR
	buf: ARRAY 512 OF CHAR;
	timeout: LONGINT;
	c: Cache;
	adr: IP.Adr;
BEGIN
	adr := IP.NilAdr;
	IF Trace THEN KernelLog.String("MailByDomain: "); KernelLog.String(domain) END;
	c := CacheFindDomain(domain);
	IF c # NIL THEN
		COPY(c.name, hostname);
		res := Ok;
	ELSE
		Lower(domain);
		QueryDNS(TypeMX, buf, domain, hostname, adr, timeout, res);
		IF (res = Ok) OR (res = BadName) THEN CacheAdd(hostname, adr, domain, timeout) END
	END;
	IF Trace THEN KernelLog.String(" res="); KernelLog.Int(res, 1); KernelLog.Ln END
END MailHostByDomain;

(** Find the IP address of the specified host. *)

PROCEDURE HostByName*(hostname: ARRAY OF CHAR; VAR adr: IP.Adr; VAR res: WORD);
VAR
	buf: ARRAY 512 OF CHAR;
	name: Name;
	timeout: LONGINT;
	c: Cache;
	dummy: ARRAY 1 OF CHAR;
BEGIN
	dummy[0] := 0X;
	adr := IP.StrToAdr(hostname);

	IF IP.IsNilAdr (adr) THEN
		IF Trace THEN KernelLog.String("HostByName: "); KernelLog.String(hostname) END;
		COPY(hostname, name); Domain(name, domain, FALSE); Lower(name);
		IF Trace THEN KernelLog.Char(" "); KernelLog.String(name) END;
		c := CacheFindName(name);
		IF c # NIL THEN
			adr := c.adr;
			IF ~IP.IsNilAdr (adr) THEN res := Ok ELSE res := BadName END
		ELSE
			adr := IP.NilAdr;
			(* Query first preferred protocol family *)
			IF IP.preferredProtocol = IP.IPv4 THEN
				QueryDNS(TypeA, buf, name, dummy, adr, timeout, res);
			ELSE
				QueryDNS(TypeAAAA, buf, name, dummy, adr, timeout, res);
			END;
			IF (res = Ok) OR (res = BadName) THEN
				CacheAdd(name, adr, dummy, timeout)
			ELSIF IP.preferredProtocol = IP.IPv4 THEN
				(* If a error occured query not preferred protocol family *)
				QueryDNS(TypeAAAA, buf, name, dummy, adr, timeout, res);
			ELSE
				QueryDNS(TypeA, buf, name, dummy, adr, timeout, res);
			END;
			IF (res = Ok) OR (res = BadName) THEN
				CacheAdd(name, adr, dummy, timeout);
			END;
		END;
		IF Trace THEN KernelLog.String(" res="); KernelLog.Int(res, 1); KernelLog.Ln END
	ELSE
		res := Ok
	END
END HostByName;

(** Find the host name of the specified IP address. *)

PROCEDURE HostByNumber*(adr: IP.Adr; VAR hostname: ARRAY OF CHAR; VAR res: WORD);
VAR
	buf: ARRAY 512 OF CHAR;
	name: Name;
	i, j, k, timeout: LONGINT;
	c: Cache;
	int: IP.Interface;
BEGIN
	IF ~IP.IsNilAdr(adr) THEN
		int := IP.InterfaceByDstIP(adr);
		IF ~int.IsBroadcast(adr) THEN
			IP.AdrToStr(adr, buf);
			IF Trace THEN KernelLog.String("HostByNumber: "); KernelLog.String(buf) END;
			c := CacheFindAdr(adr);
			IF c # NIL THEN
				COPY(c.name, hostname);
				res := Ok;
			ELSE
				hostname[0] := 0X;
				i := 0; WHILE buf[i] # 0X DO INC(i) END;
				j := 0;
				REPEAT
					WHILE (i # 0) & (buf[i] # ".") DO DEC(i) END;
					k := i;
					IF buf[i] = "." THEN INC(i) END;
					WHILE (buf[i] # ".") & (buf[i] # 0X) DO name[j] := buf[i]; INC(j); INC(i) END;
					name[j] := "."; INC(j);
					i := k-1
				UNTIL i < 0;
				name[j] := 0X;
				Domain(name, ArpaDomain, TRUE);
				IF Trace THEN KernelLog.Char(" "); KernelLog.String(name) END;
				QueryDNS(TypePTR, buf, name, hostname, adr, timeout, res);
				IF (res = Ok) OR (res = BadName) THEN CacheAdd(hostname, adr, "", timeout) END
			END;
			IF (res = Ok) & (hostname[0] = 0X) THEN res := BadName END;
			IF Trace THEN KernelLog.String(" res="); KernelLog.Int(res, 1); KernelLog.Ln END
		END;
	ELSE
		hostname[0] := 0X;
		res := BadName;
	END;
	IF res # Ok THEN
		IP.AdrToStr(adr, hostname)
	END;
END HostByNumber;

BEGIN
	(* Get domain name from configuration. *)
	Machine.GetConfig("Domain", domain);
	id := 0;
	NEW(serverlist);
	NEW(cache);
	cache.next := NIL;
	lastCleanup := Kernel.GetTicks();
END DNS.

(*
History:
02.11.2003	mvt	Adapted for new interfaces of Network, IP and UDP.
03.11.2003	mvt	Added support for MX queries (mail exchange).
21.11.2003	mvt	Support for concurrent queries.
02.05.2005	eb	Type AAAA supported
*)
