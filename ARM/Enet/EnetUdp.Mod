MODULE EnetUdp;
(**
	AUTHOR: Alexey Morozov, HighDim GmbH, 2015
	PURPOSE: Ethernet networking stack, UDP protocol
*)

IMPORT
	SYSTEM, EnetBase, Interfaces := EnetInterfaces, EnetUtils, EnetTiming, Trace := EnetTrace;

CONST
	MaxNumSockets* = 32; (** maximal number of UDP sockets *)

TYPE
	Int32 = EnetBase.Int32;
	Int16 = EnetBase.Int16;
	Int = EnetBase.Int;
	ResultCode = EnetBase.ResultCode;

	(* UDP received datagram handler *)
	RecvDatagramHandler* = PROCEDURE{DELEGATE}(
														socket: Socket;
														CONST srcAddr: EnetBase.IpAddr;
														srcPort: Int;
														VAR data: ARRAY OF CHAR;
														dataOffs, dataLen: Int;
														packet: EnetBase.Packet
														);

	(**
		UDP socket (must not be shared among multiple threads)
	*)
	Socket* = POINTER TO RECORD
		intf*: EnetBase.Interface; (** the used interface; selection of the interface is done based on the IP address of the destination *)

		localPort*: Int; (** local (source) port *)
		sendToIpAddr*: EnetBase.IpAddr; (** IP address to send to *)
		sendToPort*: Int; (** port to send to *)
		resolvedSendToIpAddr: BOOLEAN;

		recvHandler*: RecvDatagramHandler; (** installed handler of received datagrams *)
		recvHandlerParam *: ANY; (** user-defined parameter for the receiver handler *)

		sendToMacAddr*: EnetBase.MacAddr;

		sendToIpAddrLast: EnetBase.IpAddr;
		sendToMacAddrLast: EnetBase.MacAddr;

		localPortNet: Int16; (* local port in the network byte order *)
	END;

VAR
	sockets: ARRAY MaxNumSockets OF Socket;
	numSockets: Int;

	(**
		Create a UDP socket given a local port number

		localPort: local (source) port
		recvHandler: handler of received datagrams
		socket: reference to the created socket (NIL in case of an error)
		res: result code

		returns NIL in case of an error
	*)
	PROCEDURE NewSocket*(
										VAR socket: Socket;
										localPort: Int;
										VAR res: ResultCode
									): BOOLEAN;
	BEGIN
		IF numSockets >= MaxNumSockets THEN
			res := EnetBase.ErrOutOfResources;
			RETURN FALSE;
		END;
		IF (localPort < 0) OR (localPort > 65536) THEN
			res := EnetBase.ErrInvalidValue;
			RETURN FALSE;
		END;
		NEW(socket);
		socket.localPort := localPort;
		socket.sendToPort := 0;
		socket.recvHandler := NIL;

		IF EnetBase.LittleEndianSystem THEN
			socket.localPortNet := EnetUtils.SwitchEndianness16(Int16(localPort));
		ELSE
			socket.localPortNet := Int16(localPort);
		END;

		socket.sendToIpAddrLast := EnetBase.NilIpAddr;

		sockets[numSockets] := socket;
		INC(numSockets);

		res := 0;
		RETURN TRUE;
	END NewSocket;

	(**
		Setup socket's received datagram handler
	*)
	PROCEDURE SetRecvHandler*(socket: Socket; recvHandler: RecvDatagramHandler; VAR res: ResultCode): BOOLEAN;
	BEGIN
		socket.recvHandler := recvHandler;
		res := 0;
		RETURN TRUE;
	END SetRecvHandler;

	(**
		Setup default destination of datagrams sent on a given socket using Send procedure
	*)
	PROCEDURE SetDestination*(socket: Socket; CONST sendToIpAddr: EnetBase.IpAddr; sendToPort: Int; completionHandler: EnetBase.TaskHandler; VAR res: ResultCode): BOOLEAN;
	BEGIN
		IF (sendToPort <= 0) OR (sendToPort >= 65535) THEN
			res := EnetBase.ErrInvalidValue;
			RETURN FALSE;
		END;

		IF ~Interfaces.ResolveIpAddr(sendToIpAddr,socket.sendToMacAddr,socket.intf,completionHandler,res) THEN RETURN FALSE; END;
		IF res = 0 THEN socket.resolvedSendToIpAddr := TRUE;
		ELSE socket.resolvedSendToIpAddr := FALSE;
		END;
		socket.sendToIpAddr := sendToIpAddr;
		socket.sendToPort := sendToPort;
		RETURN TRUE;
	END SetDestination;

	(**
		Send a datagram on a given socket
	*)
	PROCEDURE Send*(socket: Socket; CONST data: ARRAY OF CHAR; offset, length: Int; flags: SET; completionHandler: EnetBase.TaskHandler; VAR res: ResultCode): BOOLEAN;
	VAR
		packet: EnetBase.Packet;
		intf: EnetBase.Interface;
		dev: EnetBase.LinkDevice;
		payloadOffs: Int;
	BEGIN

		IF socket.sendToPort = 0 THEN res := EnetBase.ErrInvalidValue; RETURN FALSE; END;
		IF socket.intf = NIL THEN res := EnetBase.ErrNoIntfFound; RETURN FALSE; END;

		intf := socket.intf;
		IF ~socket.resolvedSendToIpAddr THEN
			IF ~Interfaces.ResolveIpAddr(socket.sendToIpAddr,socket.sendToMacAddr,socket.intf,NIL,res) THEN RETURN FALSE; END;
		END;

		dev := intf.dev;
		IF ~Interfaces.GetTxPacket(intf,packet) THEN res := EnetBase.ErrTxPacketPoolEmpty; RETURN FALSE; END;

		IF socket.sendToIpAddr.ver = 4 THEN
			EnetBase.SetUdpPacket(packet,
									intf.dev.macAddr,
									socket.sendToMacAddr,
									intf.ipv4Addr,
									socket.sendToIpAddr,
									socket.localPort,
									socket.sendToPort,
									length
									);
		ELSE
			EnetBase.SetUdpPacket(packet,
									intf.dev.macAddr,
									socket.sendToMacAddr,
									intf.ipv6Addr,
									socket.sendToIpAddr,
									socket.localPort,
									socket.sendToPort,
									length
									);
		END;

		IF ~dev.setPacketPayload(dev,packet,data,offset,flags,res) THEN
			RETURN FALSE;
		END;

		RETURN Interfaces.SendPacket(intf,packet,flags,completionHandler,res);
	END Send;

	(**
		Send at datagram on a given socket to a specified destination
	*)
	PROCEDURE SendTo*(socket: Socket; CONST sendToIpAddr: EnetBase.IpAddr; sendToPort: LONGINT; CONST data: ARRAY OF CHAR; offset, length: Int; flags: SET; completionHandler: EnetBase.TaskHandler; VAR res: ResultCode): BOOLEAN;
	VAR
		packet: EnetBase.Packet;
		intf: EnetBase.Interface;
		dev: EnetBase.LinkDevice;
		payloadOffs: Int;
	BEGIN
		IF sendToPort = 0 THEN
			res := EnetBase.ErrInvalidValue;
			RETURN FALSE;
		END;

		IF ~(sendToIpAddr = socket.sendToIpAddrLast) THEN
			IF Interfaces.ResolveIpAddr(sendToIpAddr,socket.sendToMacAddrLast,socket.intf,NIL,res) THEN
				socket.sendToIpAddrLast := sendToIpAddr;
			ELSE RETURN FALSE;
			END;
		END;

		intf := socket.intf;
		dev := intf.dev;
		IF ~Interfaces.GetTxPacket(intf,packet) THEN
			res := EnetBase.ErrTxPacketPoolEmpty;
			RETURN FALSE;
		END;

		IF socket.sendToIpAddrLast.ver = 4 THEN
			EnetBase.SetUdpPacket(packet,
									intf.dev.macAddr,
									socket.sendToMacAddrLast,
									intf.ipv4Addr,
									socket.sendToIpAddrLast,
									socket.localPort,
									sendToPort,
									length
									);
		ELSE
			EnetBase.SetUdpPacket(packet,
									intf.dev.macAddr,
									socket.sendToMacAddrLast,
									intf.ipv6Addr,
									socket.sendToIpAddrLast,
									socket.localPort,
									sendToPort,
									length
									);
		END;

		IF ~dev.setPacketPayload(dev,packet,data,offset,flags,res) THEN
			RETURN FALSE;
		END;

		RETURN Interfaces.SendPacket(intf,packet,flags,completionHandler,res);
	END SendTo;

	(**
		Handling of an UDP packet
	*)
	PROCEDURE HandlePacket*(intf: EnetBase.Interface; packet: EnetBase.Packet; flags: SET);
	VAR
		i: Int;
		socket: Socket;
		srcPort: Int;
		dstPort: Int16;
		srcIpAddr: EnetBase.IpAddr;
		payloadOffs, payloadLen: Int;
	BEGIN
		dstPort := packet.udpHdr.dstPort;

		(*
			search a socket bound to the packet's destination port
		*)
		i := 0;
		WHILE (i < numSockets) & (dstPort # sockets[i].localPortNet) DO (*! optimize socket search (e.g. search only among the sockets with installed recv handlers etc.) *)
			INC(i);
		END;
		IF i < numSockets THEN
			IF EnetBase.EnableTrace THEN Trace.StringLn("EnetUdp: Received UDP datagram for open port " & dstPort); END;
			socket := sockets[i];
			IF socket.recvHandler # NIL THEN
				payloadOffs := SIZEOF(EnetBase.EthFrameHdr)+SIZEOF(EnetBase.UdpHdr);
				IF ~(EnetBase.FlagIpv6 IN flags) THEN (* IPv4 *)
					srcIpAddr.addr[0] := packet.ipv4Hdr.srcIpAddr;
					srcIpAddr.ver := 4;
					INC(payloadOffs,SIZEOF(EnetBase.Ipv4Hdr));
				ELSE (* IPv6 *)
					srcIpAddr.addr[0] := packet.ipv6Hdr.srcIpAddr[0];
					srcIpAddr.addr[1] := packet.ipv6Hdr.srcIpAddr[1];
					srcIpAddr.addr[2] := packet.ipv6Hdr.srcIpAddr[2];
					srcIpAddr.addr[3] := packet.ipv6Hdr.srcIpAddr[3];
					srcIpAddr.ver := 6;
					INC(payloadOffs,SIZEOF(EnetBase.Ipv6Hdr));
				END;
				srcPort := Int(EnetUtils.SwitchEndianness16(packet.udpHdr.srcPort)) MOD 10000H;
				packet.payloadOffs := payloadOffs;
				payloadLen := EnetUtils.SwitchEndianness16(packet.udpHdr.length) - SIZEOF(EnetBase.UdpHdr);
				socket.recvHandler(socket,srcIpAddr,srcPort,packet.data^,packet.dataOffs+payloadOffs,payloadLen,packet);
			END;
		ELSE
			IF EnetBase.EnableTrace THEN Trace.StringLn("EnetUdp: Received UDP datagram on closed port " & dstPort); END;
		END;

	END HandlePacket;

	PROCEDURE Install*(intf: EnetBase.Interface);
	BEGIN
		EnetBase.SetIpPacketHandler(intf,EnetBase.ProtoUdp,HandlePacket);
	END Install;
END EnetUdp.
