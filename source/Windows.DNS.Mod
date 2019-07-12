MODULE DNS;   (** fof  **)

IMPORT IP, WSock32, KernelLog,SYSTEM;

CONST
	(* error codes. *)
	Ok* = 0;  NotFound* = 3601;  BadName* = 3602;

TYPE
	DomainName* = ARRAY 64 OF CHAR;
	HostName* = ARRAY 128 OF CHAR;
	Name* = ARRAY 128 OF CHAR; (* domain or host name type *)

VAR
	server*: ARRAY 4 OF IP.Adr;
	domain*: DomainName;  currentServer*, serverCount*: LONGINT;
	trace: BOOLEAN;


	(* Find the IP address of the specified host. *)
	PROCEDURE HostByName*( hostname: ARRAY OF CHAR;  VAR adr: IP.Adr;  VAR res: WORD );
	VAR hostent: WSock32.PHostent; str: ARRAY 64 OF CHAR; addr: ADDRESS;
	BEGIN
		hostent := WSock32.gethostbyname(hostname);
		IF hostent = NIL THEN
			WSock32.DispError()
		ELSE
			adr.usedProtocol := IP.IPv4;
			(*adr.ipv4Adr := hostent.hName;*)
			SYSTEM.GET(hostent.hAddrList, addr(*adr.ipv4Adr*));
			IF addr # NIL (*adr.ipv4Adr # 0*) THEN SYSTEM.GET(addr (*adr.ipv4Adr*), adr.ipv4Adr); END;

			(*
			IP.AdrToStr(adr,str); KernelLog.String(str); KernelLog.Ln;
			adr := WSock32.ntohl( adr );(*  u_long from TCP/IP network order to host byte order*)
			IP.AdrToStr(adr,str); KernelLog.String(str); KernelLog.Ln;
			*)
		END;

		IF adr.ipv4Adr # 0 THEN res := Ok ELSE res := NotFound END;

		IF trace THEN
			IP.AdrToStr(adr,str);
			KernelLog.String( "DNS.HostByName : " );  KernelLog.String( hostname );  KernelLog.String( " : " );
			KernelLog.String( str);  KernelLog.String( " (" );  KernelLog.Int(res,1);  KernelLog.String( ")" );  KernelLog.Ln;
		END;
	END HostByName;

(* Find the host name of the specified IP address. *)
	PROCEDURE HostByNumber*( adr: IP.Adr;  VAR hostname: ARRAY OF CHAR;  VAR res: WORD );
	VAR len: WORD;
	BEGIN
		COPY( "", hostname );
		IF (adr.usedProtocol = IP.IPv4) THEN
			adr.ipv4Adr := WSock32.htonl(adr.ipv4Adr);   (*  host byte order to TCP/IP network order*)
			len := LEN(hostname)(WORD);
			len := WSock32.getpeername(adr.ipv4Adr, hostname,len);(* Dan 10.11.05 *)
		END;
		IF hostname # "" THEN res := Ok ELSE res := NotFound END;
		IF trace THEN
			IF (adr.usedProtocol = IP.IPv4) THEN
				KernelLog.String( "DNS.HostByAdr : " );  KernelLog.Int( adr.ipv4Adr, 1 );  KernelLog.String( " : " );
				KernelLog.String( hostname );  KernelLog.String( "(" );  KernelLog.Int( res, 1 );  KernelLog.String( ")" );  KernelLog.Ln;
			ELSE
				KernelLog.String("DNS.HostByAdr : Error, works only with IPv4 addresses!"); KernelLog.Ln;
			END;
		END;
	END HostByNumber;

(* Set the current domain name, and clear all domain name server addresses. *)
	PROCEDURE InstallDomain*(CONST name: ARRAY OF CHAR );
	(* do nothing, domain is handled by AosWinsock and statically by windows *)
	BEGIN
		IF trace THEN KernelLog.String( "DNS.InstallDomain : " );  KernelLog.String( name );  KernelLog.Ln;  END;
	END InstallDomain;

(* Add a domain name server to the configuration. *)
	PROCEDURE InstallDNS*( adr: IP.Adr );
	(* do nothing, DNS is done by windows *)
	BEGIN
		IF trace THEN
			KernelLog.String( "DNS.InstallDNS : " );
			IF (adr.usedProtocol = IP.IPv4) THEN KernelLog.Int( adr.ipv4Adr, 1 );
			ELSE KernelLog.String("No IPv4 address!");
			END;
			KernelLog.Ln;
		END;
	END InstallDNS;

PROCEDURE ToggleTrace*;
BEGIN
	trace := ~trace;
	IF trace THEN KernelLog.String("DNS: tracing ON"); KernelLog.Ln; ELSE KernelLog.String("DNS: tracing OFF"); KernelLog.Ln END;
END ToggleTrace;

(* Initialize the DNS client. *)

	PROCEDURE Init;
	BEGIN
		domain := "";  currentServer := 0;  serverCount := 0;
		server[0].usedProtocol := IP.IPv4;
		server[0].ipv4Adr := 0; (* NilAdr *)
		trace := FALSE;
	END Init;

BEGIN
	ASSERT( Ok = IP.Ok );  Init;
END DNS.
