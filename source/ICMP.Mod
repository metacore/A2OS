MODULE ICMP; (** AUTHOR "mvt"; PURPOSE "ICMP protocol"; *)

(*
	ICMPv4 Header

	00	08	type
	01	08	code
	02	16	checksum of icmp header and data
	04	--	contents

	ICMPv4 Echo Request/Reply Packet

	00	08	type = 8 (request) or type = 0 (reply)
	01	08	code = 0
	02	16	checksum of icmp header and data
	04	16	identifier
	06	16	sequence number
	08	--	optional data

	Notes:
	o Bit numbers above are Intel bit order.
	o Avoid use of SET because of PPC bit numbering issues.
	o Always access fields as 8-, 16- or 32-bit values and use DIV, MOD, ASH, ODD for bit access.
*)

IMPORT SYSTEM, Machine, Modules, KernelLog, IP, IPv6, Network, Strings;

CONST
	(* DEBUG *)
	DEBUG = FALSE;

	(** Error codes *)
	Ok* = 0;
	AlreadyInstalled* = 3501;
	NeverInstalled* = 3502;

	(* ICMP type exported *)
	ICMPDstUnreachable* = 1;

	(** ICMPv4 types *)
	TypeEchoReplyv4* = 0;
	TypeDstUnreachablev4 = 3;
	TypeSourceQuenchv4 = 4;
	TypeRedirectv4 = 5;
	TypeEchoRequestv4* = 8;
	TypeTimeExceededv4* = 11;

	(* ICMPv6 error types *)
	TypeDstUnreachablev6 = 1;
	TypePacketTooBigv6 = 2;
	TypeTimeExceededv6* = 3;
	TypeParamProbv6 = 4;

	(* ICMPv6 informal messages types *)
	TypeEchoRequestv6* = 128;
	TypeEchoReplyv6* = 129;

	(* Neighbor Discovery *)
	TypeNeighborSolicitation = 135;
	TypeNeighborAdvertisement = 136;
	TypeRouterSolicitation = 133;
	TypeRouterAdvertisement = 134;

	IPTypeICMPv4 = 1; (* ICMPv4 type code for IP packets *)
	IPTypeICMPv6 = 58; (* ICMPv6 type code for IP packets *)
	ICMPHdrLen = IP.ICMPHdrLen; (* length of ICMP header *)

	MaxPseudoHdrLen = 40;  (* IPv6: 40 *)
	PrefixOptHdrLen = 4;	(* 4 * 8-byte block *)
	MTUOptHdrLen = 1;		(* 1 * 8-byte block *)
	RtrAdvHdrLen = 12;		(* Router advertisement header length *)
	TimeExcHdrLen = 4;		(* ICMPv6 time exceeded header length *)
	ParamExcHdrLen = 4;	(* ICMPv6 parameter problem header length *)

TYPE
	Receiver* = PROCEDURE {DELEGATE} (int: IP.Interface; type, code: LONGINT; fip, lip: IP.Adr; buffer: Network.Buffer);

VAR
	receivers: ARRAY 256 OF Receiver; (* registered receivers - array position is ICMP packet type *)

	(* Statistic variables *)
	NICMPRcvTotal-, NICMPTooSmall-, NICMPBadChecksum-, NICMPNoReceiver-, NICMPDelivered-,
	NICMPEchoRequest-, NICMPSend-: LONGINT;

	res: WORD;

(* Receive an ICMP (v4 and v6) packet *)
PROCEDURE Input(int: IP.Interface; type: LONGINT; fip, lip: IP.Adr; buffer: Network.Buffer);
VAR
	code: LONGINT;
	receiver: Receiver;
	checksumOk: BOOLEAN;
	sum: LONGINT;
	pseudoHdrLen: LONGINT;
	pseudoHdr: ARRAY MaxPseudoHdrLen OF CHAR; (* pseudo header for calculating checksum *)
	reassembledLength: LONGINT;
	fragmentBuffer: Network.Buffer;

BEGIN
	IF DEBUG THEN
		ASSERT ((type = IPTypeICMPv6) OR (type = IPTypeICMPv4));
	END;

	Machine.AtomicInc(NICMPRcvTotal);
	IF buffer.len >= ICMPHdrLen THEN
		(* Checksum calculation of ICMPv4 and ICMPv6 is different! In ICMPv6 another pseudo header is used *)
		IF int.protocol = IP.IPv4 THEN
			checksumOk := IP.Checksum2(buffer.data, buffer.ofs, buffer.len, 0) = 0;
		ELSIF int.protocol = IP.IPv6 THEN
			(* Get checksum from header *)
			sum := Network.GetNet2(buffer.data, buffer.ofs + 2);

			IF sum # 0 THEN
				(* calculate checksum *)
				(* set pseudo header *)
				reassembledLength := 0;
				fragmentBuffer := buffer;
				WHILE fragmentBuffer # NIL DO
					INC(reassembledLength, fragmentBuffer.len);
					fragmentBuffer := fragmentBuffer.nextFragment;
				END;

				pseudoHdrLen := int.WritePseudoHeader(pseudoHdr, fip, lip, IPTypeICMPv6, reassembledLength);
				sum := IP.Checksum1(pseudoHdr, 0, pseudoHdrLen, 0);

				IF buffer.nextFragment # NIL THEN
					(* fragmented packets *)
					fragmentBuffer := buffer;
					WHILE fragmentBuffer.nextFragment # NIL DO
						sum := IP.Checksum1(fragmentBuffer.data, fragmentBuffer.ofs, fragmentBuffer.len, sum);
						fragmentBuffer := fragmentBuffer.nextFragment;
					END;

					sum := IP.Checksum2(fragmentBuffer.data, fragmentBuffer.ofs, fragmentBuffer.len, sum);
				ELSE
					sum := IP.Checksum2(buffer.data, buffer.ofs, buffer.len, sum);
				END;
			END;
			checksumOk := sum = 0;
		ELSE
			IF DEBUG THEN
				ASSERT(TRUE);
			END;
			(* interface with unknown protocol *)
			checksumOk := FALSE;
		END;

		IF checksumOk THEN
			type := ORD(buffer.data[buffer.ofs]);
			code := ORD(buffer.data[buffer.ofs+1]);
			receiver := receivers[type];

			IF receiver # NIL THEN
				(* do receiver upcall *)
				buffer.l4ofs := buffer.ofs;
				INC(buffer.ofs, ICMPHdrLen);
				DEC(buffer.len, ICMPHdrLen);
				receiver(int, type, code, fip, lip, buffer);
				Machine.AtomicInc(NICMPDelivered);
				(* Exit here w/o returning buffer because it is passed to a receiver *)
				RETURN;
			ELSE
				Machine.AtomicInc(NICMPNoReceiver);
			END;
		ELSE
			Machine.AtomicInc(NICMPBadChecksum);
		END;
	ELSE
		Machine.AtomicInc(NICMPTooSmall);
	END;
	(* Exit and return buffer here because it is no longer used *)
	Network.ReturnBuffer(buffer);
END Input;


(** Send an ICMP packet. The variables "type" and "code" must conatin the ICMP type and code information.
	interface can be set to send the ICMP message on a specific interface otherwise it is automatically slected. *)
PROCEDURE Send*(interface: IP.Interface; fip: IP.Adr; VAR data: ARRAY OF CHAR; ofs, len, type, code, TTL: LONGINT);
VAR
	hdr: ARRAY ICMPHdrLen OF CHAR;
	pseudoHdrLen: LONGINT;
	pseudoHdr: ARRAY MaxPseudoHdrLen OF CHAR; (* pseudo header for calculating checksum *)
	sum: LONGINT;

BEGIN
	(* IF no interface was given choose one *)
	IF interface = NIL THEN
		interface := IP.InterfaceByDstIP(fip);
	END;

	IF interface # NIL THEN
		Machine.AtomicInc(NICMPSend);
		(* Set ICMP header *)
		hdr[0] := CHR(type);
		hdr[1] := CHR(code);
		IF fip.usedProtocol = IP.IPv4 THEN
			Network.Put2(hdr, 2, IP.Checksum2(data, ofs, len, IP.Checksum1(hdr, 0, 2, 0)));
			interface.Send(IPTypeICMPv4, fip, hdr, data, ICMPHdrLen, ofs, len, TTL);
		ELSIF fip.usedProtocol = IP.IPv6 THEN
			(* Use pseudo header for checksum calculation *)
			(* set pseudo header *)
			pseudoHdrLen := interface.WritePseudoHeader(pseudoHdr, interface.localAdr, fip, IPTypeICMPv6, len+ICMPHdrLen);

			sum := IP.Checksum1(pseudoHdr, 0, pseudoHdrLen, 0);
			sum := IP.Checksum1(hdr, 0, ICMPHdrLen, sum);
			sum := IP.Checksum2(data, ofs, len, sum);
			Network.Put2(hdr, 2, sum); (* checksum := sum *)
			interface.Send(IPTypeICMPv6, fip, hdr, data, ICMPHdrLen, ofs, len, TTL);
		END;
	END;
END Send;


(** Send an ICMP packet. The variables "type" and "code" must conatin the ICMP type and code information.
	interface must be set. The ICMPv6 packet is directly send without cache lookups etc. *)
PROCEDURE SendDirectly*(interface: IPv6.Interface; linkDst: Network.LinkAdr; fip: IP.Adr; VAR data: ARRAY OF CHAR; ofs, len, type, code, TTL: LONGINT);
VAR
	hdr: ARRAY ICMPHdrLen OF CHAR;
	pseudoHdrLen: LONGINT;
	pseudoHdr: ARRAY MaxPseudoHdrLen OF CHAR; (* pseudo header for calculating checksum *)
	sum: LONGINT;

BEGIN
	IF DEBUG THEN
		ASSERT (interface # NIL);
		ASSERT (fip.usedProtocol = IP.IPv6);
	END;

	IF interface # NIL THEN
		Machine.AtomicInc(NICMPSend);
		(* Set ICMP header *)
		hdr[0] := CHR(type);
		hdr[1] := CHR(code);
		(* Use pseudo header for checksum calculation *)
		(* set pseudo header *)
		pseudoHdrLen := interface.WritePseudoHeader(pseudoHdr, interface.localAdr, fip, IPTypeICMPv6, len+ICMPHdrLen);

		sum := IP.Checksum1(pseudoHdr, 0, pseudoHdrLen, 0);
		sum := IP.Checksum1(hdr, 0, ICMPHdrLen, sum);
		sum := IP.Checksum2(data, ofs, len, sum);
		Network.Put2(hdr, 2, sum); (* checksum := sum *)

		interface.SendDirectly(linkDst, IPTypeICMPv6, fip, hdr, data, ICMPHdrLen, ofs, len, TTL);
	END;
END SendDirectly;


(** Install a receiver for this type *)
PROCEDURE InstallReceiver*(type: LONGINT; r: Receiver; VAR res: WORD);
BEGIN {EXCLUSIVE}
	ASSERT(r # NIL);
	ASSERT((type >=0) & (type <= 255));
	IF receivers[type] # NIL THEN
		res := AlreadyInstalled;
	ELSE
		receivers[type] := r;
		res := Ok;
	END;
END InstallReceiver;


(** Remove the currently installed receiver for this type *)
PROCEDURE RemoveReceiver*(type: LONGINT; VAR res: WORD);
BEGIN {EXCLUSIVE}
	ASSERT((type >=0) & (type <= 255));
	IF receivers[type] = NIL THEN
		res := NeverInstalled;
	ELSE
		res := Ok;
		receivers[type] := NIL;
	END;
END RemoveReceiver;


(** Standard receiver that replies echo requests *)
PROCEDURE ReplyEcho*(int: IP.Interface; type, code: LONGINT; fip, lip: IP.Adr; buffer: Network.Buffer);
VAR
	longData: POINTER TO ARRAY OF CHAR;
	fragmentBuffer: Network.Buffer;
	fragmentLen: LONGINT;
	i: LONGINT;

BEGIN
	Machine.AtomicInc(NICMPEchoRequest);
	IF ~int.IsBroadcast(lip) THEN
		IF fip.usedProtocol = IP.IPv4 THEN
			Send(int, fip, buffer.data, buffer.ofs, buffer.len, TypeEchoReplyv4, 0, IP.MaxTTL);

		ELSIF fip.usedProtocol = IP.IPv6 THEN
			IF buffer.nextFragment = NIL THEN
				Send(int, fip, buffer.data, buffer.ofs, buffer.len, TypeEchoReplyv6, 0, IP.MaxTTL);
			ELSE
				(* packet is fragmented *)
				NEW(longData, IPv6.MaxFragPacketSize);
				fragmentBuffer := buffer;
				fragmentLen := 0;
				WHILE fragmentBuffer # NIL DO
					FOR i := 0 TO fragmentBuffer.len - 1 DO
						longData^[fragmentLen + i] := fragmentBuffer.data[fragmentBuffer.ofs + i];
					END;
					INC(fragmentLen, fragmentBuffer.len);

					fragmentBuffer := fragmentBuffer.nextFragment;
				END;

				Send(int, fip, longData^, 0, fragmentLen, TypeEchoReplyv6, 0, IP.MaxTTL);
			END;
		ELSE
			IF DEBUG THEN
				ASSERT(TRUE);
			END;
			(* Unknown protocol *)
		END
	END;
	Network.ReturnBuffer(buffer);
END ReplyEcho;


(* Send a ICMP message *)
PROCEDURE SendICMP* (type: LONGINT; fip: IP.Adr; buffer: Network.Buffer);
VAR
	IPHdrLen: LONGINT; (* length of IP header to copy *)
	icmpMsg: ARRAY 72 OF CHAR; (* unused (4) + MaxIPHdrLen (60) + UDPHdrLen (8) *)

BEGIN {EXCLUSIVE}
	CASE type OF
		ICMPDstUnreachable:
			IPHdrLen := buffer.ofs - buffer.l3ofs;
			Network.Put4(icmpMsg, 0, 0); (* unused *)
			(* 8: first 8 bytes of the original datagram-s dataIP header UDP header *)
			Network.Copy(buffer.data, icmpMsg, buffer.l3ofs, 4, IPHdrLen + 8);
			Send(NIL, fip, icmpMsg, 0, 4+IPHdrLen+8, TypeDstUnreachablev4, 3, IP.MaxTTL);
		ELSE
			IF DEBUG THEN
				ASSERT(TRUE);
			END;
	END;
END SendICMP;


(* Send a Neighbor Advertisement message *)
PROCEDURE SendNeighborAdvertisement*(interface: IPv6.Interface; linkDst: Network.LinkAdr; dstAdr: IP.Adr; solicited: BOOLEAN);
VAR
	nsData: ARRAY IPv6.NeighborHdrLen + IPv6.LLAdrOptionLen OF CHAR;
	nsDataLen: LONGINT;
	i: LONGINT;
	flagsSet: SET;

BEGIN
	flagsSet := {};

	(* routerFlag *)
	IF interface.isRouter THEN
		flagsSet := flagsSet + {31};
	END;

	(* solicited flag *)
	IF solicited THEN
		flagsSet := flagsSet + {30};
	END;

	(* override flag is true *)
	flagsSet := flagsSet + {29};

	Network.PutNet4(nsData, 0, SYSTEM.VAL(LONGINT, flagsSet));	(* flags & reserved *)

	FOR i := 0 TO 3 DO		(* Target address 16 byte *)
		Network.Put4(nsData, 4+(i*4), Network.Get4(interface.localAdr.ipv6Adr, i * 4));
	END;

	IF ~IP.IsNilAdr(dstAdr) THEN
		(* Add a Source Link-Layer Address option *)
		nsDataLen := IPv6.NeighborHdrLen + IPv6.LLAdrOptionLen;
		nsData[20] := 2X;	(* Type = 2 *)
		nsData[21] := 1X;	(* Length = 1 : Ethernet MAC Address (6bytes) *)
		FOR i := 0 TO 5 DO	(* Link-Layer Address *)
			nsData[22+i] := interface.dev.local[i];
		END;
	ELSE
		nsDataLen := 20;
	END;

	(* Send packet directly without Neighbor Cache lookup etc. *)
	IF solicited THEN
		SendDirectly (interface, linkDst, dstAdr, nsData, 0, nsDataLen, TypeNeighborAdvertisement, 0, IP.MaxTTL);
	ELSE
		SendDirectly (interface, IPv6.linkMulticastAllNodesAdr, dstAdr, nsData, 0, nsDataLen, TypeNeighborAdvertisement, 0, IP.MaxTTL);
	END;
END SendNeighborAdvertisement;


(* Send a Neighbor Solicitation message *)
PROCEDURE SendNeighborSolicitation*(interface: IPv6.Interface; linkDst: Network.LinkAdr; dstAdr: IP.Adr; multicast: BOOLEAN);
VAR
	nsData: ARRAY IPv6.NeighborHdrLen + IPv6.LLAdrOptionLen OF CHAR;
	nsDataLen: LONGINT;
	solicitedNodeDstAdr: IP.Adr;
	i: LONGINT;

BEGIN
	Network.Put4(nsData, 0, 0);	(* Reserved *)

	FOR i := 0 TO 3 DO		(* Target address 16 byte *)
		Network.Put4(nsData, 4+(i*4), Network.Get4(dstAdr.ipv6Adr, i * 4));
	END;

	IF ~IP.IsNilAdr(dstAdr) THEN
		(* Add a Source Link-Layer Address option *)
		nsDataLen := IPv6.NeighborHdrLen + IPv6.LLAdrOptionLen;
		nsData[20] := 1X;	(* Type = 1 *)
		nsData[21] := 1X;	(* Length = 1 : Ethernet MAC Address (6bytes) *)
		FOR i := 0 TO 5 DO	(* Link-Layer Address *)
			nsData[22+i] := interface.dev.local[i];
		END;
	ELSE
		nsDataLen := 20;
	END;

	(* Send packet directly without Neighbor Cache lookup etc. *)
	IF multicast THEN
		solicitedNodeDstAdr := IPv6.linkLocalMulticastNodeAdr;
		FOR i := 13 TO 15 DO
			solicitedNodeDstAdr.ipv6Adr[i] := dstAdr.ipv6Adr[i];
		END;
		solicitedNodeDstAdr.ipv6Adr[11] := 1X;
		solicitedNodeDstAdr.ipv6Adr[12] := 0FFX;
		SendDirectly (interface, linkDst, solicitedNodeDstAdr, nsData, 0, nsDataLen, TypeNeighborSolicitation, 0, IP.MaxTTL);
	ELSE
		SendDirectly (interface, linkDst, dstAdr, nsData, 0, nsDataLen, TypeNeighborSolicitation, 0, IP.MaxTTL);
	END;
END SendNeighborSolicitation;


(* Send a Router Solicitation message *)
PROCEDURE SendRouterSolicitation(interface: IPv6.Interface);
VAR
	rsData: ARRAY IPv6.RouterSolHdrLen + IPv6.LLAdrOptionLen OF CHAR;
	rsDataLen: LONGINT;
	i: LONGINT;

BEGIN
	Network.Put4(rsData, 0, 0); (* Reserved *)

	(* Add a source link-layer option *)
	rsDataLen := IPv6.RouterSolHdrLen + IPv6.LLAdrOptionLen;
	rsData[4] := 1X;	(* Type = 1 *)
	rsData[5] := 1X; (* Length = 1: Ethernet MAC Address (6 bytes) *)
	FOR i := 0 TO 5 DO	(* Link-Layer Address *)
		rsData[6+i] := interface.dev.local[i];
	END;

	SendDirectly (interface, IPv6.linkMulticastAllRoutersAdr, IPv6.linkLocalMulticastRouterAdr, rsData, 0, rsDataLen, TypeRouterSolicitation, 0, IP.MaxTTL);
END SendRouterSolicitation;


(* Send a Router Advertisement message *)
PROCEDURE SendRouterAdvertisement(interface: IPv6.Interface; dstAdr: IP.Adr; dstLinkAdr: Network.LinkAdr; routerConfig: IPv6.RouterConfig);
VAR
	raData: POINTER TO ARRAY OF CHAR;
	raDataLen: LONGINT;
	nbrOfPrefixes: LONGINT;
	prefixConfigItem: IPv6.PrefixConfig;
	flags: SET;
	offset: LONGINT;
	i: LONGINT;

BEGIN
	(* Count number of prefix options *)
	nbrOfPrefixes := 0;
	prefixConfigItem := routerConfig.Prefixes;
	WHILE prefixConfigItem # NIL DO
		prefixConfigItem := prefixConfigItem.next;
		INC(nbrOfPrefixes);
	END;

	INC(raDataLen, nbrOfPrefixes * 8 * PrefixOptHdrLen);	(* prefix options header len is written in number of 8-bytes block *)

	(* Source link-layer address option *)
	INC(raDataLen, IPv6.LLAdrOptionLen);

	(* MTU option *)
	IF routerConfig.LinkMTU # 0 THEN
		INC(raDataLen, MTUOptHdrLen * 8);
	END;

	INC(raDataLen, RtrAdvHdrLen);

	NEW(raData, raDataLen);

	(* Fill packet *)
	raData^[0] := CHR(routerConfig.CurrentHopLimit);	(* Current hop limit *)

	(* Managed address configuration, other stateful configuration and home agent flag
	    Home flag is always zero. *)
	flags := {};
	IF routerConfig.ManagedAddressConfig THEN
		flags := flags + {7};
	END;
	IF routerConfig.OtherStatefulConfig THEN
		flags := flags + {6};
	END;

	raData^[1] := SYSTEM.VAL(CHAR, flags);

	Network.PutNet2(raData^, 2, routerConfig.Lifetime);
	Network.PutNet4(raData^, 4, routerConfig.ReachableTime);
	Network.PutNet4(raData^, 8, routerConfig.RetransTimer);

	offset := 12;

	(* Add a source link-layer option *)
	raData^[offset] := 1X;	(* Type = 1 *)
	raData^[offset + 1] := 1X; (* Length = 1: Ethernet MAC Address (6 bytes) *)
	FOR i := 0 TO 5 DO	(* Link-Layer Address *)
		raData^[offset + 2 + i] := interface.dev.local[i];
	END;
	INC(offset, IPv6.LLAdrOptionLen);

	(* LinkMTU option *)
	IF routerConfig.LinkMTU # 0 THEN
		raData^[offset] := 5X;
		raData^[offset+1] := 1X;
		Network.Put2(raData^, offset + 2, 0);
		Network.PutNet4(raData^, offset + 4, routerConfig.LinkMTU);

		INC(offset, 8);
	END;

	(* Prefixes *)
	prefixConfigItem := routerConfig.Prefixes;
	WHILE prefixConfigItem # NIL DO
		raData^[offset] := 3X;
		raData^[offset + 1] := 4X;
		raData^[offset + 2] := CHR(prefixConfigItem.Prefix.data);

		(* flags *)
		flags := {};
		IF prefixConfigItem.OnLink THEN
			flags := flags + {7};
		END;
		IF prefixConfigItem.Autonomous THEN
			flags := flags + {6};
		END;
		(* router address flag is always zero: Mobility support is disabled *)
		IF prefixConfigItem.IsSitePrefix THEN
			flags := flags + {4};
		END;
		raData^[offset + 3] := SYSTEM.VAL(CHAR, flags);

		Network.PutNet4(raData^, offset + 4, prefixConfigItem.ValidLifetime);
		Network.PutNet4(raData^, offset + 8, prefixConfigItem.PreferredLifetime);
		Network.Put4(raData^, offset + 12, 0);

		IF prefixConfigItem.IsSitePrefix THEN
			raData^[offset + 15] := CHR(prefixConfigItem.Prefix.data);
		END;

		FOR i := 0 TO 15 DO
			raData^[offset + 16 + i] := prefixConfigItem.Prefix.ipv6Adr[i];
		END;

		INC(offset, 8 * PrefixOptHdrLen);
		prefixConfigItem := prefixConfigItem.next;
	END;
	SendDirectly (interface, dstLinkAdr, dstAdr, raData^, 0, raDataLen, TypeRouterAdvertisement, 0, IP.MaxTTL);
END SendRouterAdvertisement;


(** Send a ICMPv6 time exceeded message *)
PROCEDURE SendICMPv6TimeExceeded(interface: IPv6.Interface; discardedPacket: Network.Buffer; srcAdr: IP.Adr; code: LONGINT);
VAR
	(* Max size of a ICMPv6 time exceeded packet including portion of discarded packet is 1280 *)
	teData: ARRAY TimeExcHdrLen + 1280 - IPv6.MaxIPHdrLen - ICMPHdrLen OF CHAR;
	teDataLen: LONGINT;
	i: LONGINT;

BEGIN
	Network.Put4(teData, 0, 0); (* Unused *)

	(* add portion of discarded packet *)
	teDataLen := Strings.Min(TimeExcHdrLen + 1280 - IPv6.MaxIPHdrLen - ICMPHdrLen, TimeExcHdrLen + discardedPacket.len);
	FOR i := TimeExcHdrLen TO teDataLen - 1 DO
		teData[i] := discardedPacket.data[i - TimeExcHdrLen];
	END;

	Send(interface, srcAdr, teData, 0, teDataLen, TypeTimeExceededv6, code, interface.curHopLimit);
END SendICMPv6TimeExceeded;


(** Send a ICMPv6 parameter problem message *)
PROCEDURE SendICMPv6ParamProb(interface: IPv6.Interface; discardedPacket: Network.Buffer; srcAdr: IP.Adr; probPointer: LONGINT; code: LONGINT);
VAR
	(* Max size of a ICMPv6 parameter problem packet including portion of discarded packet is 1280 *)
	ppData: ARRAY ParamExcHdrLen + 1280 - IPv6.MaxIPHdrLen - ICMPHdrLen OF CHAR;
	ppDataLen: LONGINT;
	i: LONGINT;

BEGIN
	Network.Put4(ppData, 0, probPointer);

	(* add portion of discarded packet *)
	ppDataLen := Strings.Min(ParamExcHdrLen + 1280 - IPv6.MaxIPHdrLen - ICMPHdrLen, ParamExcHdrLen + discardedPacket.len);
	FOR i := ParamExcHdrLen TO ppDataLen - 1 DO
		ppData[i] := discardedPacket.data[i - ParamExcHdrLen];
	END;

	Send(interface, srcAdr, ppData, 0, ppDataLen, TypeParamProbv6, code, interface.curHopLimit);
END SendICMPv6ParamProb;

(* Receive a neighbor Soliciation message *)
PROCEDURE ReceiveNeighborSolicitation (interface: IP.Interface; type, code: LONGINT; srcAdr, dstAdr: IP.Adr; buffer: Network.Buffer);
VAR
	ipv6Interface: IPv6.Interface;

BEGIN
	IF interface IS IPv6.Interface THEN
		(* Only IPv6 *)
		ipv6Interface := interface (IPv6.Interface);
		ipv6Interface.ReceiveNeighborSolicitation(srcAdr, dstAdr, buffer);

	ELSE
		IF DEBUG THEN
			ASSERT(TRUE);
		END;
		Network.ReturnBuffer(buffer);
	END;
END ReceiveNeighborSolicitation;


(* Receive a neighbor Advertisement message *)
PROCEDURE ReceiveNeighborAdvertisement (interface: IP.Interface; type, code: LONGINT; srcAdr, dstAdr: IP.Adr; buffer: Network.Buffer);
VAR
	ipv6Interface: IPv6.Interface;

BEGIN
	IF interface IS IPv6.Interface THEN
		(* Only IPv6 *)
		ipv6Interface := interface (IPv6.Interface);
		ipv6Interface.ReceiveNeighborAdvertisement (srcAdr, dstAdr, buffer);

	ELSE
		IF DEBUG THEN
			ASSERT(TRUE);
		END;
		Network.ReturnBuffer(buffer);
	END;
END ReceiveNeighborAdvertisement;


(* Receive a router solicitation message *)
PROCEDURE ReceiveRouterSolicitation(interface: IP.Interface; type, code: LONGINT; srcAdr, dstAdr: IP.Adr; buffer: Network.Buffer);
VAR
	ipv6Interface: IPv6.Interface;

BEGIN
	IF interface IS IPv6.Interface THEN
		(* Only IPv6 *)
		ipv6Interface := interface (IPv6.Interface);
		ipv6Interface.ReceiveRouterSolicitation();
	ELSE
		IF DEBUG THEN
			ASSERT(TRUE);
		END;
	END;

KernelLog.Enter;KernelLog.Ln; KernelLog.String("************************");KernelLog.Ln;
KernelLog.String("Received a router advertisement");
KernelLog.String("");
KernelLog.Ln; KernelLog.String("************************");KernelLog.Ln;KernelLog.Exit;

	Network.ReturnBuffer(buffer);
END ReceiveRouterSolicitation;


(* Receive a router advertisement message *)
PROCEDURE ReceiveRouterAdvertisement (interface: IP.Interface; type, code: LONGINT; srcAdr, dstAdr: IP.Adr; buffer: Network.Buffer);
VAR
	ipv6Interface: IPv6.Interface;

BEGIN
	IF interface IS IPv6.Interface THEN
		(* Only IPv6 *)
		ipv6Interface := interface (IPv6.Interface);
		ipv6Interface.ReceiveRouterAdvertisement(srcAdr, buffer);
	ELSE
		IF DEBUG THEN
			ASSERT(TRUE);
		END;
		Network.ReturnBuffer(buffer);
	END;
END ReceiveRouterAdvertisement;


(* Receive a packet too big message *)
PROCEDURE ReceivePacketTooBig (interface: IP.Interface; type, code: LONGINT; srcAdr, dstAdr: IP.Adr; buffer: Network.Buffer);
VAR
	ipv6Interface: IPv6.Interface;

BEGIN
	IF interface IS IPv6.Interface THEN
		(* Only IPv6 *)
		ipv6Interface := interface(IPv6.Interface);
		ipv6Interface.ReceivePacketTooBig(srcAdr, buffer);
	ELSE
		IF DEBUG THEN
			ASSERT(TRUE);
		END;
		Network.ReturnBuffer(buffer);
	END;
END ReceivePacketTooBig;


(** Reads Source or Target Link-Layer address option. Buffer.ofs has to be set to the Type byte*)
PROCEDURE LinkLayerAdrOption (VAR buffer: Network.Buffer; VAR linkAdr: Network.LinkAdr);
VAR
	i: LONGINT;

BEGIN
	IF DEBUG THEN
		(* Type is Source or Target Link *)
		ASSERT ((buffer.data[buffer.ofs] = 1X) OR (buffer.data[buffer.ofs] = 2X));
	END;

	FOR i := 0 TO 5 DO
		linkAdr[i] := buffer.data[buffer.ofs + i + 2];
	END;
	linkAdr[6] := 0X;
	linkAdr[7] := 0X;

	DEC(buffer.len, 8 * ORD(buffer.data[buffer.ofs + 1]));
	INC(buffer.ofs, 8 * ORD(buffer.data[buffer.ofs + 1]));
END LinkLayerAdrOption;


(* Reads ICMP prefix information option *)
PROCEDURE PrefixInfoOption(VAR buffer: Network.Buffer;
							   VAR onLink: BOOLEAN;
							   VAR autonomous: BOOLEAN;
							   VAR routerAddress: BOOLEAN;
							   VAR sitePrefix: BOOLEAN;
							   VAR validLifetime: LONGINT;
							   VAR preferredLifetime: LONGINT;
							   VAR sitePrefixLength: LONGINT;
							   VAR prefix: IP.Adr);
VAR
	flags: SET;
	i: LONGINT;

BEGIN
	prefix.data := ORD(buffer.data[buffer.ofs + 2]);

	flags := SYSTEM.VAL(SET, buffer.data[buffer.ofs + 3]);

	onLink := 7 IN flags;
	autonomous := 6 IN flags;
	routerAddress := 5 IN flags;
	sitePrefix := 4 IN flags;

	validLifetime := Network.GetNet4(buffer.data, buffer.ofs + 4);
	preferredLifetime := Network.GetNet4(buffer.data, buffer.ofs + 8);
	sitePrefixLength := ORD(buffer.data[buffer.ofs + 15]);

	prefix.usedProtocol := IP.IPv6;
	FOR i := 0 TO 15 DO
		prefix.ipv6Adr[i] := buffer.data[buffer.ofs + 16 + i]
	END;

	DEC(buffer.len, 8 * ORD(buffer.data[buffer.ofs + 1]));
	INC(buffer.ofs, 8 * ORD(buffer.data[buffer.ofs + 1]));	(* Length field times 8 bytes*)
END PrefixInfoOption;


(* Reads ICMP redirect header option *)
PROCEDURE RedirectHdrOption(VAR buffer: Network.Buffer);
BEGIN
	DEC(buffer.len, 8 * ORD(buffer.data[buffer.ofs + 1]));
	INC(buffer.ofs, 8 * ORD(buffer.data[buffer.ofs + 1]));	(* Length field times 8 bytes*)
END RedirectHdrOption;


(* Reads ICMP MTU option *)
PROCEDURE MTUOption(VAR buffer: Network.Buffer; VAR MTU: LONGINT);
BEGIN
	MTU := Network.GetNet4(buffer.data, buffer.ofs + 4);

	DEC(buffer.len, 8 * ORD(buffer.data[buffer.ofs + 1]));
	INC(buffer.ofs, 8 * ORD(buffer.data[buffer.ofs + 1]));	(* Length field times 8 bytes*)
END MTUOption;


(* Reads ICMP advertisement interval option *)
PROCEDURE AdvIntervalOption(VAR buffer: Network.Buffer);
BEGIN
	DEC(buffer.len, 8 * ORD(buffer.data[buffer.ofs + 1]));
	INC(buffer.ofs, 8 * ORD(buffer.data[buffer.ofs + 1]));	(* Length field times 8 bytes*)
END AdvIntervalOption;


(* Reads ICMP home agent information option *)
PROCEDURE HomeAgentInfoOption(VAR buffer: Network.Buffer);
BEGIN
	DEC(buffer.len, 8 * ORD(buffer.data[buffer.ofs + 1]));
	INC(buffer.ofs, 8 * ORD(buffer.data[buffer.ofs + 1]));	(* Length field times 8 bytes*)
END HomeAgentInfoOption;


(* Reads ICMP route information option *)
PROCEDURE RouteInfoOption(VAR buffer: Network.Buffer);
BEGIN
	DEC(buffer.len, 8 * ORD(buffer.data[buffer.ofs + 1]));
	INC(buffer.ofs, 8 * ORD(buffer.data[buffer.ofs + 1]));	(* Length field times 8 bytes*)
END RouteInfoOption;


PROCEDURE Cleanup;
VAR
	res: WORD;

BEGIN
	IPv6.sendNeighborSolicitation := NIL;
	IPv6.sendNeighborAdvertisement := NIL;
	IPv6.sendRouterSolicitation := NIL;
	IPv6.sendRouterAdvertisement := NIL;
	IPv6.icmpLinkLayerAdrOption := NIL;
	IPv6.icmpPrefixInfoOption := NIL;
	IPv6.icmpRedirectHdrOption := NIL;
	IPv6.icmpMTUOption := NIL;
	IPv6.icmpAdvIntervalOption := NIL;
	IPv6.icmpHomeAgentInfoOption := NIL;
	IPv6.icmpRouteInfoOption := NIL;

	(* Remove ICMP receivers *)
	RemoveReceiver(TypeEchoRequestv4, res);
	IF DEBUG THEN ASSERT (res = Ok) END;
	RemoveReceiver(TypeEchoRequestv6, res);
	IF DEBUG THEN ASSERT (res = Ok) END;
	RemoveReceiver(TypeNeighborSolicitation, res);
	IF DEBUG THEN ASSERT (res = Ok) END;
	RemoveReceiver(TypeNeighborAdvertisement, res);
	IF DEBUG THEN ASSERT (res = Ok) END;
	RemoveReceiver(TypeRouterAdvertisement, res);
	IF DEBUG THEN ASSERT (res = Ok) END;
	RemoveReceiver(TypeRouterSolicitation, res);
	IF DEBUG THEN ASSERT (res = Ok) END;
	RemoveReceiver(TypePacketTooBigv6, res);
	IF DEBUG THEN ASSERT (res = Ok) END;

	(* Remove IP receivers *)
	IP.RemoveReceiver(IPTypeICMPv4);
	IP.RemoveReceiver(IPTypeICMPv6);
END Cleanup;


PROCEDURE InitDelegates*;
BEGIN
	(* set delegates in IPv6 *)
	IPv6.sendNeighborSolicitation := SendNeighborSolicitation;
	IPv6.sendNeighborAdvertisement := SendNeighborAdvertisement;
	IPv6.sendRouterAdvertisement := SendRouterAdvertisement;
	IPv6.sendRouterSolicitation := SendRouterSolicitation;
	IPv6.sendICMPv6TimeExceeded := SendICMPv6TimeExceeded;
	IPv6.sendICMPv6ParamProb := SendICMPv6ParamProb;
	IPv6.icmpLinkLayerAdrOption := LinkLayerAdrOption;
	IPv6.icmpPrefixInfoOption := PrefixInfoOption;
	IPv6.icmpRedirectHdrOption := RedirectHdrOption;
	IPv6.icmpMTUOption := MTUOption;
	IPv6.icmpAdvIntervalOption := AdvIntervalOption;
	IPv6.icmpHomeAgentInfoOption := HomeAgentInfoOption;
	IPv6.icmpRouteInfoOption := RouteInfoOption;
END InitDelegates;


BEGIN
	IF (IP.EchoReply) THEN
		(* install internal echoRequest receiver *)
		InstallReceiver(TypeEchoRequestv4, ReplyEcho, res);
		IF DEBUG THEN ASSERT (res = Ok) END;
		InstallReceiver(TypeEchoRequestv6, ReplyEcho, res);
		IF DEBUG THEN  ASSERT (res = Ok) END;

		(* Install neighbor discovery reiceivers *)
		InstallReceiver(TypeNeighborSolicitation, ReceiveNeighborSolicitation, res);
		IF DEBUG THEN ASSERT (res = Ok) END;
		InstallReceiver(TypeNeighborAdvertisement, ReceiveNeighborAdvertisement, res);
		IF DEBUG THEN ASSERT (res = Ok) END;

		(* Router Advertisement *)
		InstallReceiver(TypeRouterAdvertisement, ReceiveRouterAdvertisement, res);
		IF DEBUG THEN ASSERT (res = Ok) END;

		(* Router Solicitation *)
		InstallReceiver(TypeRouterSolicitation, ReceiveRouterSolicitation, res);
		IF DEBUG THEN ASSERT (res = Ok) END;

		(* Packet too big *)
		InstallReceiver(TypePacketTooBigv6, ReceivePacketTooBig, res);
		IF DEBUG THEN ASSERT (res = Ok) END;
	END;
	IP.InstallReceiver(IPTypeICMPv4, Input);
	IP.InstallReceiver(IPTypeICMPv6, Input);
	Modules.InstallTermHandler(Cleanup);
END ICMP.

(*
History:
21.10.2003	mvt	Created and moved the ICMP impelementation from the IP module to this one.
26.10.2003	mvt	Adapted to new design of IP.
02.05.2005	eb	IPv6 (Neighbor Discovery / EchoRequest / EchoReply
*)
