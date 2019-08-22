MODULE EnetInterfaces;
(**
	AUTHOR: Alexey Morozov, HighDim GmbH, 2015
	PURPOSE: Ethernet networking stack, network interface management
*)

IMPORT
	S := SYSTEM, EnetBase, EnetTiming;

CONST
	MaxNumInterfaces*  = 2; (** maximal number of supported network interfaces *)

TYPE
	Int32 = EnetBase.Int32;
	Int16 = EnetBase.Int16;
	Int = EnetBase.Int;
	UInt = EnetBase.UInt;
	ResultCode = EnetBase.ResultCode;

	Packet = EnetBase.Packet;
	IpAddr = EnetBase.IpAddr;
	MacAddr = EnetBase.MacAddr;

	Interface = EnetBase.Interface;

VAR
	intfs-: ARRAY MaxNumInterfaces OF Interface;
	numIntfs-: LONGINT;

	(** plugable locks for concurrent manipulation of the interface list *)
	acquireIntfsWrite*, releaseIntfsWrite*: PROCEDURE{DELEGATE}();
	acquireIntfsRead*, releaseIntfsRead*: PROCEDURE{DELEGATE}();

	(**
		Initialize an interface; must be preallocated
	*)
	PROCEDURE InitInterface*(
										intf: Interface;
										dev: EnetBase.LinkDevice;
										VAR res: ResultCode
										): BOOLEAN;
	BEGIN
		IF intf = NIL THEN res := EnetBase.ErrInvalidValue; RETURN FALSE; END;
		EnetBase.InitInterface(intf);
		IF dev = NIL THEN res := EnetBase.ErrInvalidValue; RETURN FALSE; END;
		intf.dev := dev;
		dev.intf := intf;

		res := 0;
		RETURN TRUE;
	END InitInterface;

	(**
		Register an interface
	*)
	PROCEDURE Add*(intf: Interface; VAR res: ResultCode): BOOLEAN;
	VAR
		b: BOOLEAN;
		i: Int;
	BEGIN
		IF EnetBase.ThreadSafe THEN acquireIntfsWrite; END;

		IF numIntfs < LEN(intfs) THEN
			(* do not allow to add an interface twice *)
			i := 0;
			WHILE (i < numIntfs) & (intfs[i] # intf) DO INC(i); END;
			IF i = numIntfs THEN
				intfs[numIntfs] := intf;
				INC(numIntfs);
				res := 0; b := TRUE;
			ELSE
				res := EnetBase.ErrAlreadyExists; b := FALSE;
			END;
		ELSE
			res := EnetBase.ErrOutOfBounds; b := FALSE;
		END;

		IF EnetBase.ThreadSafe THEN releaseIntfsWrite; END;

		RETURN b;
	END Add;

	(**
		Start a network interface; thread-safe in case if multithreading is enabled
	*)
	PROCEDURE Start*(intf: Interface; VAR res: ResultCode): BOOLEAN;
	VAR b: BOOLEAN;
	BEGIN
		IF EnetBase.ThreadSafe THEN intf.dev.acquireTx; intf.dev.acquireRx; END;
		b := intf.start(intf,res);
		IF EnetBase.ThreadSafe THEN intf.dev.releaseTx; intf.dev.releaseRx; END;
		RETURN b;
	END Start;

	(**
		Start all network interfaces
	*)
	PROCEDURE StartAll*(VAR res: ResultCode): BOOLEAN;
	VAR i: Int; r: ResultCode;
	BEGIN
		IF EnetBase.ThreadSafe THEN acquireIntfsRead; END;
		res := 0;
		FOR i := 0 TO numIntfs-1 DO
			IF ~Start(intfs[i],r) THEN res := r; END;
		END;
		IF EnetBase.ThreadSafe THEN releaseIntfsRead; END;
		RETURN res = 0;
	END StartAll;

	(**
		Stop a network interface; thread-safe in case if multithreading is enabled
	*)
	PROCEDURE Stop*(intf: Interface; VAR res: ResultCode): BOOLEAN;
	VAR b: BOOLEAN;
	BEGIN
		IF EnetBase.ThreadSafe THEN intf.dev.acquireTx; intf.dev.acquireRx; END;
		b := intf.stop(intf,res);
		IF EnetBase.ThreadSafe THEN intf.dev.releaseTx; intf.dev.releaseRx; END;
		RETURN b;
	END Stop;

	(**
		Stop all network interfaces
	*)
	PROCEDURE StopAll*(VAR res: ResultCode): BOOLEAN;
	VAR i: Int; r: ResultCode;
	BEGIN
		IF EnetBase.ThreadSafe THEN acquireIntfsRead; END;
		res := 0;
		FOR i := 0 TO numIntfs-1 DO
			IF ~Stop(intfs[i],r) THEN res := r; END;
		END;
		IF EnetBase.ThreadSafe THEN releaseIntfsRead; END;
		RETURN res = 0;
	END StopAll;

	(**
		Reset a network interface; thread-safe in case if multithreading is enabled
	*)
	PROCEDURE Reset*(intf: Interface; VAR res: ResultCode): BOOLEAN;
	VAR b: BOOLEAN;
	BEGIN
		IF EnetBase.ThreadSafe THEN intf.dev.acquireTx; intf.dev.acquireRx; END;
		b := intf.reset(intf,res);
		IF EnetBase.ThreadSafe THEN intf.dev.releaseTx; intf.dev.releaseRx; END;
		RETURN b;
	END Reset;

	(**
		Reset all network interfaces
	*)
	PROCEDURE ResetAll*(VAR res: ResultCode): BOOLEAN;
	VAR i: Int; r: ResultCode;
	BEGIN
		IF EnetBase.ThreadSafe THEN acquireIntfsRead; END;
		res := 0;
		FOR i := 0 TO numIntfs-1 DO
			IF ~Reset(intfs[i],r) THEN res := r; END;
		END;
		IF EnetBase.ThreadSafe THEN releaseIntfsRead; END;
		RETURN res = 0;
	END ResetAll;

	(**
		Set MAC address for a given network interface
	*)
	PROCEDURE SetMacAddr*(intf: Interface; CONST macAddr: MacAddr; VAR res: ResultCode): BOOLEAN;
	VAR b: BOOLEAN;
	BEGIN
		IF EnetBase.ThreadSafe THEN intf.dev.acquireTx; intf.dev.acquireRx; END;
		b := intf.dev.setMacAddr(intf.dev,macAddr,res);
		IF EnetBase.ThreadSafe THEN intf.dev.releaseTx; intf.dev.releaseRx; END;
		RETURN b;
	END SetMacAddr;

	(**
		Setup interface link
	*)
	PROCEDURE SetLinkSpeed*(intf: Interface; CONST linkSpeed: ARRAY OF CHAR; fullDuplex: BOOLEAN; VAR res: ResultCode): BOOLEAN;
	VAR b: BOOLEAN;
	BEGIN
		IF EnetBase.ThreadSafe THEN intf.dev.acquireTx; intf.dev.acquireRx; END;
		b := intf.dev.setLinkSpeed(intf.dev,linkSpeed,fullDuplex,res);
		IF EnetBase.ThreadSafe THEN intf.dev.releaseTx; intf.dev.releaseRx; END;
		RETURN b;
	END SetLinkSpeed;

	(**
		Setup IP configuration for a given network interface
	*)
	PROCEDURE SetIpConfig*(
										intf: Interface;
										CONST ipAddr: IpAddr;
										CONST subnetMask: IpAddr;
										CONST gateway: IpAddr;
										VAR res: ResultCode
										): BOOLEAN;
	VAR b: BOOLEAN;
	BEGIN
		ASSERT(intf # NIL);

		IF (ipAddr.ver # 4) & (ipAddr.ver # 6) THEN res := EnetBase.ErrInvalidValue; RETURN FALSE; END;
		IF (gateway.ver # ipAddr.ver) OR (subnetMask.ver # ipAddr.ver) THEN res := EnetBase.ErrInvalidValue; RETURN FALSE; END;

		IF EnetBase.ThreadSafe THEN intf.dev.acquireTx; intf.dev.acquireRx; END;

		IF ipAddr.ver = 4 THEN
			intf.ipv4Addr := ipAddr;
			intf.ipv4SubnetMask := subnetMask;
			intf.ipv4Gateway := gateway;

			intf.ipv4Prefix := S.VAL(UInt,S.VAL(SET,UInt(ipAddr.addr[0])) * S.VAL(SET,UInt(subnetMask.addr[0])));
		ELSE
			intf.ipv6Addr := ipAddr;
			intf.ipv6SubnetMask := subnetMask;
			intf.ipv6Gateway := gateway;

			intf.ipv6Prefix.addr[0] := S.VAL(UInt,S.VAL(SET,UInt(ipAddr.addr[0])) * S.VAL(SET,UInt(subnetMask.addr[0])));
			intf.ipv6Prefix.addr[1] := S.VAL(UInt,S.VAL(SET,UInt(ipAddr.addr[1])) * S.VAL(SET,UInt(subnetMask.addr[1])));
			intf.ipv6Prefix.addr[2] := S.VAL(UInt,S.VAL(SET,UInt(ipAddr.addr[2])) * S.VAL(SET,UInt(subnetMask.addr[2])));
			intf.ipv6Prefix.addr[3] := S.VAL(UInt,S.VAL(SET,UInt(ipAddr.addr[3])) * S.VAL(SET,UInt(subnetMask.addr[3])));
		END;

		IF EnetBase.ThreadSafe THEN intf.dev.releaseTx; intf.dev.releaseRx; END;

		RETURN TRUE;
	END SetIpConfig;

	(**
		Get a packet for transmission from a packet pool of a given interface; thread-safe
	*)
	PROCEDURE GetTxPacket*(intf: Interface; VAR packet: Packet): BOOLEAN;
	VAR b: BOOLEAN;
	BEGIN
		IF EnetBase.ThreadSafe THEN intf.dev.txPacketPool.acquire; END;
		b := EnetBase.PacketFifoGet(intf.dev.txPacketPool,packet);
		IF EnetBase.ThreadSafe THEN intf.dev.txPacketPool.release; END;
		RETURN b;
	END GetTxPacket;

	(**
		Send a packet via a given interface; thread-safe
	*)
	PROCEDURE SendPacket*(intf: Interface; packet: Packet; flags: SET; completionHandler: EnetBase.TaskHandler; VAR res: ResultCode): BOOLEAN;
	VAR b: BOOLEAN;
	BEGIN
		IF EnetBase.ThreadSafe THEN intf.dev.acquireTx; END;
		b := intf.dev.sendPacket(intf.dev,packet,flags,completionHandler,res);
		IF EnetBase.ThreadSafe THEN intf.dev.releaseTx; END;
		RETURN b;
	END SendPacket;

	(**
		Forward an Ethernet packet to a given destination
	*)
	PROCEDURE ForwardEth*(intf: Interface; packet: Packet; CONST dstMacAddr: MacAddr; flags: SET; completionHandler: EnetBase.TaskHandler; VAR res: ResultCode): BOOLEAN;
	BEGIN
		packet.ethFrameHdr.dstMacAddr := dstMacAddr;
		packet.ethFrameHdr.srcMacAddr := intf.dev.macAddr;
		RETURN SendPacket(intf,packet,flags,completionHandler,res);
	END ForwardEth;

	(** Send a reply based on the received packet at the level of Ethernet *)
	PROCEDURE ReplyEth*(intf: Interface; packet: Packet; flags: SET; completionHandler: EnetBase.TaskHandler; VAR res: ResultCode): BOOLEAN;
	BEGIN
		packet.ethFrameHdr.dstMacAddr := packet.ethFrameHdr.srcMacAddr;
		packet.ethFrameHdr.srcMacAddr := intf.dev.macAddr;
		RETURN SendPacket(intf,packet,flags,completionHandler,res);
	END ReplyEth;

	(** Forward an IP packet to a given destination *)
	PROCEDURE ForwardIp*(intf: Interface; packet: Packet; CONST dstIpAddr: IpAddr; CONST dstMacAddr: MacAddr; flags: SET; completionHandler: EnetBase.TaskHandler; VAR res: ResultCode): BOOLEAN;
	BEGIN
		IF EnetBase.FlagIpv6 IN flags THEN (* IPv6 *)
			HALT(100);
		ELSE (* IPv4 *)
			packet.ipv4Hdr.dstIpAddr := dstIpAddr.addr[0];
			packet.ipv4Hdr.srcIpAddr := intf.ipv4Addr.addr[0];
		END;
		RETURN ForwardEth(intf,packet,dstMacAddr,flags,completionHandler,res);
	END ForwardIp;

	(** Send a reply based on the received packet at the level of IP protocol *)
	PROCEDURE ReplyIp*(intf: Interface; packet: Packet; flags: SET; completionHandler: EnetBase.TaskHandler; VAR res: ResultCode): BOOLEAN;
	BEGIN
		IF EnetBase.FlagIpv6 IN flags THEN (* IPv6 *)
			HALT(100);
		ELSE (* IPv4 *)
			packet.ipv4Hdr.dstIpAddr := packet.ipv4Hdr.srcIpAddr;
			packet.ipv4Hdr.srcIpAddr := intf.ipv4Addr.addr[0];
		END;
		RETURN ReplyEth(intf,packet,flags,completionHandler,res);
	END ReplyIp;

	(** Forward an UDP packet to a given destination *)
	PROCEDURE ForwardUdp*(intf: Interface; packet: Packet; CONST dstIpAddr: IpAddr; srcPort, dstPort: Int16; CONST dstMacAddr: MacAddr; flags: SET; completionHandler: EnetBase.TaskHandler; VAR res: ResultCode): BOOLEAN;
	BEGIN
		packet.udpHdr.srcPort := srcPort;
		packet.udpHdr.dstPort := dstPort;
		RETURN ForwardIp(intf,packet,dstIpAddr,dstMacAddr,flags,completionHandler,res);
	END ForwardUdp;

	(** Send a reply based on the received packet at the level of UDP protocol *)
	PROCEDURE ReplyUdp*(intf: Interface; packet: Packet; flags: SET; completionHandler: EnetBase.TaskHandler; VAR res: ResultCode): BOOLEAN;
	VAR port: Int16;
	BEGIN
		(*
			swap source and destination ports
		*)
		port := packet.udpHdr.dstPort;
		packet.udpHdr.dstPort := packet.udpHdr.srcPort;
		packet.udpHdr.srcPort := port;
		RETURN ReplyIp(intf,packet,flags,completionHandler,res);
	END ReplyUdp;

	(** Resolve an IP address *)
	PROCEDURE ResolveIpAddr*(CONST ipAddr: IpAddr; VAR macAddr: MacAddr; VAR intf: Interface; completionHandler: EnetBase.TaskHandler; VAR res: ResultCode): BOOLEAN;
	VAR
		i: Int;
		b: BOOLEAN;
	BEGIN
		IF EnetBase.ThreadSafe THEN acquireIntfsRead; END;

		FOR i := 0 TO numIntfs-1 DO

			intf := intfs[i];

			IF EnetBase.IpAddrFromSameSubnet(intf,ipAddr) THEN

				IF ipAddr.ver = 4 THEN
					IF intf.ipv4AddrResolve # NIL THEN
						b := intf.ipv4AddrResolve(intf,ipAddr,macAddr,completionHandler,res);
					ELSE
						res := EnetBase.ErrInvalidValue; b := FALSE;
					END;
				ELSE
					IF intf.ipv6AddrResolve # NIL THEN
						b := intf.ipv6AddrResolve(intf,ipAddr,macAddr,completionHandler,res);
					ELSE
						res := EnetBase.ErrInvalidValue; b := FALSE;
					END;
				END;

				IF EnetBase.ThreadSafe THEN releaseIntfsRead; END;
				RETURN b;
			END;
		END;

		(* the specified IP address is not local to any of the available interfaces *)

		IF EnetBase.ThreadSafe THEN releaseIntfsRead; END;

		res := EnetBase.ErrUnresolvedAddr;
		RETURN FALSE;
	END ResolveIpAddr;

	(** Update the state of a network interface; to be called regularly in a loop *)
	PROCEDURE Update*(intf: Interface; VAR res: ResultCode): BOOLEAN;
	VAR b: BOOLEAN;
	BEGIN

		IF EnetBase.ThreadSafe THEN intf.dev.acquireRx; END;
		b := intf.dev.updateRx(intf.dev,res);
		IF EnetBase.ThreadSafe THEN intf.dev.releaseRx; END;
		IF ~b THEN RETURN FALSE; END;

		IF EnetBase.ThreadSafe THEN intf.dev.acquireTx; END;
		b := intf.dev.updateTx(intf.dev,res);
		IF EnetBase.ThreadSafe THEN intf.dev.releaseTx; END;
		IF ~b THEN RETURN FALSE; END;

		IF ~EnetBase.ProcessIntfRecvPackets(intf,res) OR ~EnetBase.ProcessIntfTasks(intf,res) THEN RETURN FALSE; END;

		res := 0;
		RETURN TRUE;
	END Update;

	(**
		Update the state of all network interfaces
	*)
	PROCEDURE UpdateAll*(VAR res: ResultCode): BOOLEAN;
	VAR i: Int; r: ResultCode;
	BEGIN
		IF EnetBase.ThreadSafe THEN acquireIntfsRead; END;
		res := 0;
		FOR i := 0 TO numIntfs-1 DO
			IF ~Update(intfs[i],r) THEN res := r; END;
		END;
		IF EnetBase.ThreadSafe THEN releaseIntfsRead; END;
		RETURN res = 0;
	END UpdateAll;

END EnetInterfaces.
