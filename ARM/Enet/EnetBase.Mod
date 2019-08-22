MODULE EnetBase;
(**
	AUTHOR: Alexey Morozov, HighDim GmbH, 2015
	PURPOSE: Ethernet networking stack
*)

IMPORT
	S := SYSTEM, EnetEnvironment, EnetUtils, Trace := EnetTrace, EnetTiming;

TYPE
	Int8* = SHORTINT;
	Int16* = INTEGER;
	Int32* = LONGINT;

	Int* = SIZE; (** system signed integer type *)
	UInt* = ADDRESS; (** system unsigned integer type *)
	
	ResultCode* = WORD;

	UnalignedInt32 = EnetUtils.UnalignedInt32;

CONST

	ThreadSafe* = FALSE; (** set to TRUE to enable thread safety features *)

	LittleEndianSystem* = TRUE; (** TRUE if the system has little endian data ordering *)

	(** Link speed values in Mbps *)
	LinkSpeedAuto* = "Auto";
	Mbps10* = "10";
	Mbps100* = "100";
	Mbps1000* = "1000";

	MaxNumEthFrameHandlers* = 32; (** maximal number of plugable custom Ethernet frame handlers *)

	(** Basic Ethernet frame types *)
	EtherTypeIpv4* = 0x0008;
	EtherTypeIpv6* = 0xDD86;
	EtherTypeArp* = 0x0608;

	(**
		Protocols on top of IP (Level 3)
	*)
	ProtoIcmp* = 0x01; (** ICMP *)
	ProtoTcp* = 0x06; (** TCP *)
	ProtoUdp* = 0x11; (** UDP *)

	(**
		IP-specific constants
	*)
	IpDiffServ* = 0; (* default value of "Differentiated Services" field in an IP packet *)
	IpEcn* = 0; (** default value of  "Explicit Congestion Notification" field in an IP packet *)
	IpTtl* = 255; (** time to live for an IP packet *)

	(**
		Packet sending flags
	*)
	FlagNoDataCopy* = 0; (** do not copy user-provided data for sending a packet, the data will be used by reference; use completion handlers to assure that the data is not referenced anymore *)
	FlagNoFlushDCache* = 1; (** avoid flushing data cache for the user-provided data (used for platforms with explicit cache manipulation e.g. ARM) *)

	(**
		Packet handling flags
	*)
	FlagIpv6* = 0; (** passed to the IP packet handler to indicate IP version 6 *)

	(**
		Error codes
	*)
	OpInProgress* = -1; (** operation is still in progress *)

	ErrInvalidValue* = 1; (** a parameter has invalid value *)
	ErrTimeoutExpired* = 2; (** timeout has expired *)
	ErrCannotDoWhenActive* = 3; (** operation cannot be performed when the interface/device is active *)
	ErrNotActive* = 4; (** operation cannot be performed when the interface/device is not active *)
	ErrNoIntfFound* = 5; (** no interface found to perform a given operation *)
	ErrUnresolvedAddr* = 6; (** address not resolved error *)
	ErrOutOfResources* = 7; (** out of resources *)
	ErrOutOfBounds* = 8; (** out of bounds *)
	ErrAlreadyExists* = 9; (** an object already exists *)

	(**
		PHY-specific error codes
	*)
	ErrMdioBusy* = 10; (** MDIO interface is busy *)
	ErrPhyNotDetected* = 11; (** PHY device is not detected *)
	ErrSpeedAutonegoFailure* = 12; (** a failure to autonegotiate the link speed *)

	(**
		Link device specific error codes
	*)
	ErrRxPacketPoolEmpty* = 13; (** RX packet pool got empty *)
	ErrRxPacketPoolFull* = 14; (** RX packet pool got full *)
	ErrRecvPacketFifoFull* = 15; (** received packet FIFO got full *)
	ErrTxPacketPoolEmpty* = 16; (** TX packet pool got empty *)

	EnableTrace * = FALSE;

TYPE

	(**
		MAC address
	*)
	MacAddr* = RECORD
		addr*: ARRAY 6 OF Int8;
	END;

	IpAddr* = RECORD
		addr*: ARRAY 4 OF Int32;
		ver*: Int8;
	END;

	(** Ethernet frame header (14 bytes) *)
	EthFrameHdr* = RECORD
		dstMacAddr*: MacAddr; (** destination MAC address *)
		srcMacAddr*: MacAddr; (** source MAC address *)
		etherType*{ALIGNED(1)}: Int16; (** type of the Ethernet frame; value >= 1536 corresponds to a Ethernet II frame *)
	END;

	(**
		IP version 4 packet header (20 bytes)
	*)
	Ipv4Hdr* = RECORD
		verAndIhl*: Int8; (** 4-bit version field (4 for For IPv4) and 4-bit value of Internet Header Length (IHL) *)
		dscpAndEcn*: Int8; (** 6-bit Differentiated Services Code Point (DSCP) and 2-bit Explicit Congestion Notification (ECN) *)
		length*{ALIGNED(1)}: Int16; (** 16-bit size of the entire packet (fragment), including header and data, in bytes *)
		fragmentId*{ALIGNED(1)}: Int16; (** identification field and is primarily used for uniquely identifying the group of fragments of a single IP datagram *)
		flagsAndFragmentOffs*{ALIGNED(1)}: Int16; (** 3-bit flags field used to control or identify fragments and 13-bit fragment offset field, measured in units of eight-byte blocks (64 bits), and specifies the offset of a particular fragment relative to the beginning of the original unfragmented IP datagram *)
		ttl*: Int8; (** Time To Live (TTL) *)
		protocol*: Int8; (** defines the protocol used in the data portion of the IP datagram *)
		checksum*{ALIGNED(1)}: Int16; (** header checksum *)
		srcIpAddr*{ALIGNED(1)}: UnalignedInt32; (** source IPv4 address *)
		dstIpAddr*{ALIGNED(1)}: UnalignedInt32; (** destination IPv4 address *)
	END;

	(**
		IP version 6 packet header (XY bytes)
	*)
	Ipv6Hdr* = RECORD
		protocol*: Int8; (** defines the protocol used in the data portion of the IP datagram *)

		srcIpAddr*{ALIGNED(1)}: ARRAY 4 OF UnalignedInt32; (** source IPv6 address *)
		dstIpAddr*{ALIGNED(1)}: ARRAY 4 OF UnalignedInt32; (** destination IPv6 address *)
	END;

	(**
		Address Resolution Protocol (ARP) packet header (28 bytes)
	*)
	ArpHdr* = RECORD
		hwType*{ALIGNED(1)}: Int16;
		protoType*{ALIGNED(1)}: Int16;
		hwAddrLen*: Int8;
		protoAddrLen*: Int8;
		operation*{ALIGNED(1)}: Int16;
		srcMacAddr*: MacAddr;
		srcIpAddr*{ALIGNED(1)}: UnalignedInt32;
		dstMacAddr*: MacAddr;
		dstIpAddr*{ALIGNED(1)}: UnalignedInt32;
	END;

	(**
		Internet Control Message Protocol (ICMP) packet basic part of the header (4 bytes)
	*)
	IcmpHdr0* = RECORD
		type*: Int8; (** message type *)
		code*: Int8; (** message subtype *)
		checksum*{ALIGNED(1)}: Int16; (** checksum computed from the header and data *)
	END;

	(**
		ICMP header (8 bytes)
	*)
	IcmpHdr* = RECORD(IcmpHdr0)
		restOfHdr*{ALIGNED(1)}: UnalignedInt32; (** rest of the header (content depends on the value of "type" field) *)
	END;

	(**
		ICMP echo request/reply header
	*)
	IcmpEchoHdr* = RECORD(IcmpHdr0)
		id*{ALIGNED(1)}: Int16; (** echo message identifier *)
		seq*{ALIGNED(1)}: Int16; (** echo message sequence number *)
	END;

	(**
		User Datagram Protocol header (8 bytes)
	*)
	UdpHdr* = RECORD
		srcPort*{ALIGNED(1)}: Int16; (**  sender's port number when meaningful and should be assumed to be the port to reply to if needed *)
		dstPort*{ALIGNED(1)}: Int16; (** receiver's port number *)
		length*{ALIGNED(1)}: Int16; (**  length of the UDP header and UDP data, in bytes *)
		checksum*{ALIGNED(1)}: Int16; (** checksum computed from the header and data *)
	END;

	(** Transmit Control Protocol header (XY bytes) *)
	TcpHdr* = RECORD

	END;

	(**
		Network packet
	*)
	Packet* = POINTER TO PacketDesc;
	PacketDesc* = RECORD
		data*: POINTER TO ARRAY OF CHAR; (** packet data *)
		dataOffs*: Int; (** data array offset (set up by the corresponding link device) *)
		dataLen*: Int; (** packet data length in bytes *)

		(* Level 2 *)
		ethFrameHdr*: POINTER{UNSAFE,UNTRACED} TO EthFrameHdr;
		(* Level 3 *)
		ipv4Hdr*: POINTER{UNSAFE,UNTRACED} TO Ipv4Hdr;
		ipv6Hdr*: POINTER{UNSAFE,UNTRACED} TO Ipv6Hdr;
		arpHdr*: POINTER{UNSAFE,UNTRACED} TO ArpHdr;
		(* Level 4 *)
		icmpHdr*: POINTER{UNSAFE,UNTRACED} TO IcmpHdr;
		udpHdr*: POINTER{UNSAFE,UNTRACED} TO UdpHdr;
		tcpHdr*: POINTER{UNSAFE,UNTRACED} TO TcpHdr;

		payloadOffs*: Int; (** payload offset for the top level protocol, relative to dataOffs *)

		ownedByDev*: BOOLEAN; (** TRUE if the packet is owned by a link device and cannot be used by the user *)
		ownedByUser*: BOOLEAN; (** TRUE if the packet is owned by the user *)

		ownerPool*: PacketFifo; (** owner pool of the packet; used for returning received packets *)

		intf*: Interface;
	END;

	(** procedure type for handling packets received from an interface *)
	PacketHandler* = PROCEDURE(intf: Interface; packet: Packet; flags: SET);

	(**
		Ethernet frame handler descriptor
	*)
	EthFrameHandlerDesc* = RECORD
		etherType*: Int16;
		packetHandler*: PacketHandler;
	END;

	(** IP address cache *)
	IpAddrCache* = POINTER TO IpAddrCacheDesc;
	IpAddrCacheDesc* = RECORD
		cleanCache*: PROCEDURE{DELEGATE}(cache: IpAddrCache; cleanStatic: BOOLEAN);
		addStaticEntry*: PROCEDURE{DELEGATE}(cache: IpAddrCache; CONST ipAddr: IpAddr; CONST macAddr: MacAddr; VAR res: ResultCode): BOOLEAN;
		enumerateEntries*: PROCEDURE{DELEGATE}(cache: IpAddrCache; enumerator: PROCEDURE{DELEGATE}(entry: IpAddrCacheEntry));
		acquireWrite*, acquireRead*: PROCEDURE{DELEGATE}();
		releaseWrite*, releaseRead*: PROCEDURE{DELEGATE}();

		intf*: Interface;
	END;

	(** an entry of an IP address cache *)
	IpAddrCacheEntry* = POINTER TO IpAddrCacheEntryDesc;
	IpAddrCacheEntryDesc* = RECORD
		ipAddr*: IpAddr;
		macAddr*: MacAddr;
	END;

	(** IP address resolution procedure *)
	IpAddrResolver* = PROCEDURE{DELEGATE}(intf: Interface; CONST ipAddr: IpAddr; VAR macAddr: MacAddr; completionHandler: TaskHandler; VAR res: ResultCode): BOOLEAN;

	(**
		Network interface
	*)
	Interface* = POINTER TO InterfaceDesc;
	InterfaceDesc* = RECORD

		start*, stop*, reset*, finalize*: PROCEDURE{DELEGATE}(intf: Interface; VAR res: ResultCode): BOOLEAN;

		(**
			IPv4 network settings
		*)
		ipv4Addr*: IpAddr; (** IPv4 address of the interface *)
		ipv4SubnetMask*: IpAddr; (** IPv4 subnet mask *)
		ipv4Prefix*: Int32; (** IPv4 address prefix *)
		ipv4Gateway*: IpAddr; (** IPv4 default gateway address *)

		(**
			IPv6 network settings
		*)
		ipv6Addr*: IpAddr; (** IPv6 address of the interface *)
		ipv6SubnetMask*: IpAddr; (** IPv6 subnetwork mask *)
		ipv6Prefix*: IpAddr; (** IPv6 address prefix *)
		ipv6Gateway*: IpAddr; (** IPv6 default gateway address *)

		dev*: LinkDevice; (** Link device *)

		(** plugable LAN IPv4 address resolution functionality *)
		ipv4AddrCache*: IpAddrCache; (** IPv4 address resolution cache *)
		ipv4AddrResolve*: IpAddrResolver;

		(** plugable LAN IPv6 address resolution functionality *)
		ipv6AddrCache*: IpAddrCache; (** IPv6 address resolution cache *)
		ipv6AddrResolve*: IpAddrResolver;

		(* interface-specific periodic and non-periodic tasks *)
		nonPeriodicTasks, periodicTasks: TaskHandler;
		acquireTasks*, releaseTasks*: PROCEDURE{DELEGATE}();

		ethFrameHandlers: ARRAY MaxNumEthFrameHandlers OF EthFrameHandlerDesc;
		numEthFrameHandlers: Int;
		ipPacketHandlers: ARRAY 256 OF PacketHandler;

		(* packet handlers for basic protocols *)
		arpHandler: PacketHandler;
		icmpHandler: PacketHandler;
		udpHandler: PacketHandler;
		tcpHandler: PacketHandler;
	END;

	(**
		Ethernet link device

		all methods are thread unsafe!
	*)
	LinkDevice* = POINTER TO LinkDeviceDesc;
	LinkDeviceDesc* = RECORD
		macAddr*: MacAddr; (** MAC address of the device *)

		phyWrite*: PROCEDURE(dev: LinkDevice; phyAddr, regAddr: UInt; data: UInt; VAR res: ResultCode): BOOLEAN;
		phyRead*: PROCEDURE(dev: LinkDevice; phyAddr, regAddr: UInt; VAR data: UInt; VAR res: ResultCode): BOOLEAN;
		setMacAddr*: PROCEDURE(dev: LinkDevice; CONST macAddr: MacAddr; VAR res: ResultCode): BOOLEAN;
		setLinkSpeed*: PROCEDURE(dev: LinkDevice; CONST speed: ARRAY OF CHAR; fullDuplex: BOOLEAN; VAR res: ResultCode): BOOLEAN;
		setOptions*: PROCEDURE(dev: LinkDevice; optionsPage: Int; options: SET; VAR res: ResultCode): BOOLEAN;
		start*, stop*, reset*, finalize*: PROCEDURE(dev: LinkDevice; VAR res: ResultCode): BOOLEAN;
		newPacket*: PROCEDURE(): Packet;
		setPacketPayload*: PROCEDURE(dev: LinkDevice; packet: Packet; CONST data: ARRAY OF CHAR; offset: Int; flags: SET; VAR res: ResultCode): BOOLEAN;
		sendPacket*: PROCEDURE(dev: LinkDevice; packet: Packet; flags: SET; completionHandler: TaskHandler; VAR res: ResultCode): BOOLEAN;

		updateRx*: PROCEDURE(dev: LinkDevice; VAR res: ResultCode): BOOLEAN; (** update receive path *)
		updateTx*: PROCEDURE(dev: LinkDevice; VAR res: ResultCode): BOOLEAN; (** update transmit path *)

		rxPacketPool*: PacketFifo;
		txPacketPool*: PacketFifo;

		linkState*: BOOLEAN; (** TRUE if the link is establshed *)
		linkSpeed*: ARRAY 32 OF CHAR; (** textual representation of the link speed in Mbps *)
		fullDuplex*: BOOLEAN; (** TRUE for full duplex link, otherwise the link is half-duplex *)

		recvPackets*: PacketFifo; (** ordered list (FIFO) of received packets *)
		isActive*: BOOLEAN; (** TRUE if device is active *)

		acquireRx*, acquireTx*: PROCEDURE{DELEGATE}();
		releaseRx*, releaseTx*: PROCEDURE{DELEGATE}();

		intf*: Interface;
	END;

	(**
		Packet FIFO buffer
	*)
	PacketFifo* = POINTER TO PacketFifoDesc;
	PacketFifoDesc* = RECORD
		packets*: POINTER TO ARRAY OF Packet;
		count*: Int; (** number of packets in the FIFO *)
		wrPos*: Int; (** write pointer position *)
		rdPos*: Int; (** read pointer position *)

		acquire*, release*: PROCEDURE{DELEGATE}(); (** locks used when thread-safety is enabled *)
	END;

	(**
		Task handler descriptor
	*)
	TaskHandler* = POINTER TO TaskHandlerDesc;
	TaskHandlerDesc* = RECORD
		res*: Int; (** result code *)
		handle*: PROCEDURE{DELEGATE}(handler: TaskHandler); (** handler procedure *)
		param*: ANY; (** handler parameter *)
		next*: TaskHandler; (** linked list of handlers *)

		(* used for task management *)
		taskExpireTime, taskInterval: EnetTiming.Time;
		prevTask, nextTask: TaskHandler;
	END;

	(**
		Initialization of a network interface descriptor

		intf: interface to initialize, must be preallocated
	*)
	PROCEDURE InitInterface*(intf: Interface);
	VAR i: Int;
	BEGIN
		intf.ipv4Addr := NilIpAddr;
		intf.ipv4Gateway := NilIpAddr;
		intf.ipv4SubnetMask := NilIpAddr;
		intf.ipv4Prefix := 0;

		intf.ipv6Addr := NilIpAddr;
		intf.ipv6Gateway := NilIpAddr;
		intf.ipv6SubnetMask := NilIpAddr;
		intf.ipv6Prefix := NilIpAddr;

		intf.numEthFrameHandlers := 0;
		FOR i := 0 TO LEN(intf.ipPacketHandlers)-1 DO intf.ipPacketHandlers[i] := NIL; END;

		intf.arpHandler := NIL;
		intf.icmpHandler := NIL;
		intf.udpHandler := NIL;
		intf.tcpHandler := NIL;

		intf.dev := NIL;
	END InitInterface;

	(**
		Return a packet to its owner pool; thread-safe in case if multithreading is enabled
	*)
	PROCEDURE ReturnPacketToOwnerPool*(packet: Packet): BOOLEAN;
	VAR b: BOOLEAN;
	BEGIN
		IF ThreadSafe THEN packet.ownerPool.acquire; END;
		b := PacketFifoPut(packet.ownerPool,packet);
		IF ThreadSafe THEN packet.ownerPool.release; END;
		RETURN b;
	END ReturnPacketToOwnerPool;

	(**
		Process received packets for agiven interface
	*)
	PROCEDURE ProcessIntfRecvPackets*(intf: Interface; VAR res: ResultCode): BOOLEAN;
	VAR
		packet: Packet;
		packetHandler: PacketHandler;
		flags: SET;
		level4Hdr: ADDRESS;
		i: Int;
	BEGIN
		WHILE PacketFifoGet(intf.dev.recvPackets,packet) DO

			ASSERT(~packet.ownedByDev & ~packet.ownedByUser);

			packet.intf := intf;

			flags := {};
			packetHandler := NIL;

			(*
				Packet dispatching
			*)
			IF packet.ethFrameHdr.etherType = EtherTypeIpv4 THEN
				level4Hdr := ADDRESSOF(packet.ipv4Hdr^) + SIZEOF(Ipv4Hdr);
				CASE packet.ipv4Hdr.protocol OF
					|ProtoIcmp: packet.icmpHdr := level4Hdr; packetHandler := intf.icmpHandler;
					|ProtoUdp: packet.udpHdr := level4Hdr; packetHandler := intf.udpHandler;
					|ProtoTcp: packet.tcpHdr := level4Hdr; packetHandler := intf.tcpHandler;
				ELSE
					packetHandler := intf.ipPacketHandlers[Int(packet.ipv4Hdr.protocol) MOD 100H];
				END;
			ELSIF packet.ethFrameHdr.etherType = EtherTypeIpv6 THEN
				INCL(flags,FlagIpv6);
				level4Hdr := ADDRESSOF(packet.ipv6Hdr^) + SIZEOF(Ipv6Hdr);
				CASE packet.ipv6Hdr.protocol OF
					|ProtoIcmp: packet.icmpHdr := level4Hdr; packetHandler := intf.icmpHandler;
					|ProtoUdp: packet.udpHdr := level4Hdr; packetHandler := intf.udpHandler;
					|ProtoTcp: packet.tcpHdr := level4Hdr; packetHandler := intf.tcpHandler;
				ELSE
					packetHandler := intf.ipPacketHandlers[Int(packet.ipv4Hdr.protocol) MOD 100H];
				END;
			ELSIF packet.ethFrameHdr.etherType = EtherTypeArp THEN
				packetHandler := intf.arpHandler;
			ELSE
				i := 0;
				WHILE (i < intf.numEthFrameHandlers) & (intf.ethFrameHandlers[i].etherType # packet.ethFrameHdr.etherType) DO
					INC(i);
				END;
				IF i < intf.numEthFrameHandlers THEN packetHandler := intf.ethFrameHandlers[i].packetHandler; END;
			END;

			IF packetHandler # NIL THEN packetHandler(intf,packet,flags); END;

			IF ~packet.ownedByUser & ~packet.ownedByDev THEN (* put packet to the receive packet pool *)
				ASSERT(packet.ownerPool = intf.dev.rxPacketPool);
				IF ~ReturnPacketToOwnerPool(packet) THEN res := ErrRxPacketPoolFull; RETURN FALSE; END;
			END;

		END;

		res := 0;
		RETURN TRUE;
	END ProcessIntfRecvPackets;

	(**
		Process interface-specific tasks
	*)
	PROCEDURE ProcessIntfTasks*(intf: Interface; VAR res: ResultCode): BOOLEAN;
	VAR
		t: EnetTiming.Time;
		task: TaskHandler;
	BEGIN

		(*
			execute non-periodic tasks
		*)
		IF intf.nonPeriodicTasks # NIL THEN
			IF ThreadSafe THEN intf.acquireTasks; END;
			task := intf.nonPeriodicTasks;
			t := EnetTiming.getTimeCounter();
			WHILE (task # NIL) & (task.taskExpireTime - t  <= 0) DO
				(*Trace.String("executing non-periodic task...");*)
				task.handle(task);
				task := task.nextTask;
				(*Trace.StringLn(" Done!, (task=NIL)=" & (task = NIL));*)
			END;
			intf.nonPeriodicTasks := task;
			IF ThreadSafe THEN intf.releaseTasks; END;
		END;

		(*
			execute periodic tasks
		*)
		IF intf.periodicTasks # NIL THEN
			IF ThreadSafe THEN intf.acquireTasks; END;
			task := intf.periodicTasks;
			t := EnetTiming.getTimeCounter();
			WHILE (task # NIL) & (task.taskExpireTime - t  <= 0) DO
				task.handle(task);
				task.taskExpireTime := t + task.taskInterval;
				task := task.nextTask;
			END;
			IF ThreadSafe THEN intf.releaseTasks; END;
		END;

		res := 0;
		RETURN TRUE;
	END ProcessIntfTasks;

	(**
		Setup an Ethernet frame handler for a given network interface
	*)
	PROCEDURE SetEthFrameHandler*(intf: Interface; etherType: Int16; packetHandler: PacketHandler);
	VAR i: Int;
	BEGIN
		ASSERT(packetHandler # NIL);
		i := 0; WHILE (i < intf.numEthFrameHandlers) & (intf.ethFrameHandlers[i].etherType # etherType) DO INC(i); END;
		ASSERT(i = intf.numEthFrameHandlers);
		IF etherType = EtherTypeArp THEN
			intf.arpHandler := packetHandler;
		ELSE
			i := intf.numEthFrameHandlers;
			intf.ethFrameHandlers[i].etherType := etherType;
			intf.ethFrameHandlers[i].packetHandler := packetHandler;
		END;
	END SetEthFrameHandler;

	(**
		Setup an IP packet handler for a given network interface
	*)
	PROCEDURE SetIpPacketHandler*(intf: Interface; protocol: Int8; packetHandler: PacketHandler);
	BEGIN
		IF protocol = ProtoIcmp THEN intf.icmpHandler := packetHandler;
		ELSIF protocol = ProtoTcp THEN intf.tcpHandler := packetHandler;
		ELSIF protocol = ProtoUdp THEN intf.udpHandler := packetHandler;
		ELSE
			intf.ipPacketHandlers[Int(protocol) MOD 100H] := packetHandler;
		END;
	END SetIpPacketHandler;

	(**
		Initialize a network packet

		packet: packet to initialize, must be preallocated
	*)
	PROCEDURE InitPacket*(packet: Packet);
	VAR
		level2Hdr: ADDRESS;
		level3Hdr: ADDRESS;
	BEGIN
		ASSERT(packet # NIL);
		ASSERT(packet.data # NIL);
		level2Hdr := ADDRESSOF(packet.data[packet.dataOffs]);
		packet.ethFrameHdr := level2Hdr;

		level3Hdr := level2Hdr + SIZEOF(EthFrameHdr);
		packet.arpHdr := level3Hdr;
		packet.ipv4Hdr := level3Hdr;
		packet.ipv6Hdr := level3Hdr;

		(* will be set up in runtime *)
		packet.icmpHdr := NIL;
		packet.udpHdr := NIL;
		packet.tcpHdr := NIL;
	END InitPacket;

	(**
		Create a packet FIFO

		allocSize: FIFO size to allocate
	*)
	PROCEDURE NewPacketFifo*(allocSize: Int): PacketFifo;
	VAR fifo: PacketFifo;
	BEGIN
		NEW(fifo);
		NEW(fifo.packets,allocSize);
		fifo.wrPos := 0;
		fifo.rdPos := 0;
		fifo.count := 0;
		RETURN fifo;
	END NewPacketFifo;

	(**
		Put an entry into a packet FIFO

		Returns TRUE in case of success, FALSE indicates that the FIFO is full
	*)
	PROCEDURE PacketFifoPut*(fifo: PacketFifo; packet: Packet): BOOLEAN;
	BEGIN
		IF fifo.count < LEN(fifo.packets) THEN
			fifo.packets[fifo.wrPos] := packet;
			INC(fifo.wrPos); IF fifo.wrPos >= LEN(fifo.packets) THEN fifo.wrPos := 0; END;
			INC(fifo.count);
			RETURN TRUE;
		ELSE
			RETURN FALSE;
		END;
	END PacketFifoPut;

	(**
		Get an entry from a packet FIFO

		Returns TRUE in case of success, FALSE indicates that the FIFO is empty
	*)
	PROCEDURE PacketFifoGet*(fifo: PacketFifo; VAR packet: Packet): BOOLEAN;
	BEGIN
		IF fifo.count > 0 THEN
			packet := fifo.packets[fifo.rdPos];
			INC(fifo.rdPos); IF fifo.rdPos >= LEN(fifo.packets) THEN fifo.rdPos := 0; END;
			DEC(fifo.count);
			RETURN TRUE;
		ELSE
			RETURN FALSE;
		END;
	END PacketFifoGet;

	(**
		Schedule a task

		task: the task handler to execute
		periodic: TRUE for a periodic task
		interval: time interval in time counts after the expiration of which the specified task will be executed
	*)
	PROCEDURE ScheduleTask*(intf: Interface; task: TaskHandler; periodic: BOOLEAN; interval: EnetTiming.Time);
	VAR
		handler, handlerPrev: TaskHandler;

		PROCEDURE PutTask(VAR taskList: TaskHandler; task: TaskHandler);
		BEGIN
			(* put the task into the list of tasks - the earliest task to execute first *)
			IF taskList # NIL THEN

				handler := taskList;
				IF task.taskExpireTime - handler.taskExpireTime <= 0 THEN (* the task is the earliest to execute *)
					task.prevTask := NIL;
					task.nextTask := handler;
					handler.prevTask := task;
					taskList := task;
				ELSE
					REPEAT
						handlerPrev := handler;
						handler := handler.nextTask;
					UNTIL (handler = NIL) OR (task.taskExpireTime - handler.taskExpireTime <= 0);
					IF handler # NIL THEN (* put the task in between handlerPrev and handler *)
						task.prevTask := handler.prevTask;
						task.nextTask := handler;
						handler.prevTask := task;
					ELSE (* the task is the latest to execute *)
						task.prevTask := handlerPrev;
						task.nextTask := NIL;
						handlerPrev.nextTask := task;
					END;
				END;

			ELSE
				task.prevTask := NIL;
				task.nextTask := NIL;
				taskList := task;
			END;
		END PutTask;

	BEGIN
		ASSERT(task.handle # NIL);
		ASSERT(interval > 0);

		IF ThreadSafe THEN intf.acquireTasks; END;

		task.taskExpireTime := EnetTiming.getTimeCounter() + interval;
		IF periodic THEN
			task.taskInterval := interval;
			PutTask(intf.periodicTasks,task);
		ELSE
			PutTask(intf.nonPeriodicTasks,task);
		END;

		IF ThreadSafe THEN intf.releaseTasks; END;
	END ScheduleTask;

	(**
		Remove a scheduled task
	*)
	PROCEDURE RemoveTask*(intf: Interface; task: TaskHandler);
	BEGIN
		IF ThreadSafe THEN intf.acquireTasks; END;

		IF task.prevTask # NIL THEN
			task.prevTask.nextTask := task.nextTask;
		ELSIF task = intf.nonPeriodicTasks THEN
			intf.nonPeriodicTasks := task.nextTask;
		ELSIF task = intf.periodicTasks THEN
			intf.periodicTasks := task.nextTask;
		END;
		IF task.nextTask # NIL THEN task.nextTask.prevTask := task.prevTask; END;
		task.nextTask := NIL;
		task.prevTask := NIL;

		IF ThreadSafe THEN intf.releaseTasks; END;
	END RemoveTask;

	PROCEDURE LinkTaskHandlers*(chain, handlerToLink: TaskHandler);
	BEGIN
		ASSERT(chain # handlerToLink);
		handlerToLink.next := chain.next;
		chain.next := handlerToLink;
	END LinkTaskHandlers;

	(* Returns TRUE if a given character represents a decimal digit *)
	PROCEDURE IsDecDigit(ch: CHAR): BOOLEAN;
	BEGIN
		RETURN (ORD(ch) >= ORD('0')) & (ORD(ch) <= ORD('9'));
	END IsDecDigit;

	(* Returns TRUE if a given character represents a hexadecimal digit *)
	PROCEDURE IsHexDigit(ch: CHAR): BOOLEAN;
	BEGIN
		RETURN ((ORD(ch) >= ORD('0')) & (ORD(ch) <= ORD('9'))) OR ((ORD(CAP(ch)) >= ORD('A')) & (ORD(CAP(ch)) <= ORD('F')));
	END IsHexDigit;

	PROCEDURE DecDigitToInt(digit: CHAR): Int;
	BEGIN
		RETURN ORD(digit) - ORD('0');
	END DecDigitToInt;

	PROCEDURE HexDigitToInt(digit: CHAR): Int;
	BEGIN
		IF IsDecDigit(digit) THEN
			RETURN ORD(digit) - ORD('0');
		ELSE
			RETURN ORD(CAP(digit)) - ORD('A') + 10;
		END;
	END HexDigitToInt;

	(* Parse a word from a string representation of an IP or MAC address *)
	PROCEDURE ParseAddrWord(
											CONST strIp: ARRAY OF CHAR;
											VAR pos: Int;
											delim: CHAR;
											maxNumDigits: Int;
											hex, lastWord: BOOLEAN;
											VAR word: Int
											): BOOLEAN;
	VAR
		k, len: Int;
		strWord: ARRAY 8 OF CHAR;
		digitCondProc: PROCEDURE(ch: CHAR): BOOLEAN;
	BEGIN
		IF ~hex THEN digitCondProc := IsDecDigit;
		ELSE digitCondProc := IsHexDigit;
		END;

		len := 0;
		WHILE (pos < LEN(strIp)) & digitCondProc(strIp[pos]) & (len < maxNumDigits) DO strWord[len] := strIp[pos]; INC(pos); INC(len); END;
		IF ~lastWord THEN
			IF (pos = LEN(strIp)) OR (strIp[pos] # delim) OR (len = 0)  THEN RETURN FALSE; END;
		ELSE
			IF (pos = LEN(strIp)) OR (strIp[pos] # 0X) OR (len = 0)  THEN RETURN FALSE; END;
		END;
		strWord[len] := 0X;

		IF ~hex THEN (* decimal *)
			word := DecDigitToInt(strWord[0]);
			k := 1; DEC(len);
			WHILE len > 0 DO
				word := word*10 + DecDigitToInt(strWord[k]);
				INC(k); DEC(len);
			END;
		ELSE (* hexadecimal *)
			word := HexDigitToInt(strWord[0]);
			k := 1; DEC(len);
			WHILE len > 0 DO
				word := word*16 + HexDigitToInt(strWord[k]);
				INC(k); DEC(len);
			END;
		END;

		RETURN TRUE;
	END ParseAddrWord;

	(**
		Compose an IP address given its textual representation
	*)
	PROCEDURE StrToIpAddr*(CONST strIpAddr: ARRAY OF CHAR; VAR ipAddr: IpAddr): BOOLEAN;
	VAR
		d: ARRAY 8 OF Int;
		i, k: Int;
	BEGIN

		i := 0;
		IF ParseAddrWord(strIpAddr,i,".",3,FALSE,FALSE,d[0]) THEN
			FOR k := 1 TO 3 DO
				INC(i);
				IF ~ParseAddrWord(strIpAddr,i,".",3,FALSE,k=3,d[k]) THEN RETURN FALSE; END;
			END;
			ipAddr.addr[0] := Int32(d[3])*1000000H + Int32(d[2])*10000H + Int32(d[1])*100H + Int32(d[0]);
			ipAddr.ver := 4;
			RETURN TRUE;
		ELSIF ParseAddrWord(strIpAddr,i,":",4,TRUE,FALSE,d[0]) THEN
			FOR k := 1 TO 7 DO
				INC(i);
				IF ~ParseAddrWord(strIpAddr,i,".",3,FALSE,k=7,d[k]) THEN RETURN FALSE; END;
			END;
			(*!TODO: not sure whether this is correct, check it *)
			ipAddr.addr[0] := Int32(d[0])*10000H + Int32(d[1]);
			ipAddr.addr[1] := Int32(d[2])*10000H + Int32(d[3]);
			ipAddr.addr[2] := Int32(d[4])*10000H + Int32(d[5]);
			ipAddr.addr[3] := Int32(d[6])*10000H + Int32(d[7]);
			ipAddr.ver := 6;
			RETURN TRUE;
		END;

		RETURN FALSE;
	END StrToIpAddr;

	(**
		Write a textual representation of an IP address.
	*)
	PROCEDURE IpAddrToStr*(CONST ipAddr: IpAddr; VAR strIpAddr: ARRAY OF CHAR): BOOLEAN;
	VAR
		int: ARRAY 16 OF CHAR;
	BEGIN
		IF ~IsValidIpAddr(ipAddr) THEN RETURN FALSE END;
		IF ipAddr.ver = 4 THEN
			EnetUtils.IntToStr(ipAddr.addr[0] MOD 100H, strIpAddr);
			EnetUtils.StrAppend(strIpAddr, ".");

			EnetUtils.IntToStr(ipAddr.addr[0] DIV 100H MOD 100H, int);
			EnetUtils.StrAppend(strIpAddr, int);
			EnetUtils.StrAppend(strIpAddr, ".");

			EnetUtils.IntToStr(ipAddr.addr[0] DIV 10000H MOD 100H, int);
			EnetUtils.StrAppend(strIpAddr, int);
			EnetUtils.StrAppend(strIpAddr, ".");

			EnetUtils.IntToStr(ipAddr.addr[0] DIV 1000000H MOD 100H, int);
			EnetUtils.StrAppend(strIpAddr, int);
		ELSIF ipAddr.ver = 6 THEN
		ELSE
			RETURN FALSE
		END;
		RETURN TRUE
	END IpAddrToStr;

	(**
		Compose a MAC address given its textual representation
	*)
	PROCEDURE StrToMacAddr*(CONST strMacAddr: ARRAY OF CHAR; VAR macAddr: MacAddr): BOOLEAN;
	VAR
		i, k, d: Int;
	BEGIN

		i := 0;
		IF ParseAddrWord(strMacAddr,i,":",2,TRUE,FALSE,d) THEN
			macAddr.addr[0] := Int8(d);
			FOR k := 1 TO 5 DO
				INC(i);
				IF ~ParseAddrWord(strMacAddr,i,":",3,TRUE,k=5,d) THEN RETURN FALSE; END;
				macAddr.addr[k] := Int8(d);
			END;
			RETURN TRUE;
		END;

		RETURN FALSE;
	END StrToMacAddr;

	(** Returns TRUE if a given IP address is valid *)
	PROCEDURE IsValidIpAddr*(CONST ipAddr: IpAddr): BOOLEAN;
	BEGIN
		RETURN (ipAddr.ver = 4) OR (ipAddr.ver = 6);
	END IsValidIpAddr;

	(**
		Setup an Ethernet frame
	*)
	PROCEDURE SetEthFrame*(
										packet: Packet;
										CONST srcMacAddr, dstMacAddr: MacAddr;
										etherType: Int16;
										dataLen: Int
										);
	BEGIN
		packet.ethFrameHdr.dstMacAddr := dstMacAddr;
		packet.ethFrameHdr.srcMacAddr := srcMacAddr;
		packet.ethFrameHdr.etherType := etherType;

		packet.payloadOffs := SIZEOF(EthFrameHdr);
		packet.dataLen := dataLen+SIZEOF(EthFrameHdr);
	END SetEthFrame;

	(**
		Setup an IP packet header
	*)
	PROCEDURE SetIpPacket*(
										packet: Packet;
										CONST srcMacAddr, dstMacAddr: MacAddr;
										CONST srcIpAddr, dstIpAddr: IpAddr;
										protocol: Int8;
										ipDataLen: Int
										);
	BEGIN
		ASSERT(srcIpAddr.ver = dstIpAddr.ver);
		IF srcIpAddr.ver = 4 THEN
			SetEthFrame(packet,srcMacAddr,dstMacAddr,EtherTypeIpv4,ipDataLen+SIZEOF(Ipv4Hdr));
			packet.ipv4Hdr.verAndIhl := 0x40 + (SIZEOF(Ipv4Hdr) DIV 4);
			packet.ipv4Hdr.dscpAndEcn := Int8(IpDiffServ+IpEcn); (* type-of-service on outgoing datagrams *)
			IF LittleEndianSystem THEN
				packet.ipv4Hdr.length := EnetUtils.SwitchEndianness16(Int16(ipDataLen+SIZEOF(Ipv4Hdr)));
			ELSE
				packet.ipv4Hdr.length := Int16(ipDataLen+SIZEOF(Ipv4Hdr));
			END;
			packet.ipv4Hdr.fragmentId := 0; (*! since no fragmentation is allowed the identification field is omitted (according to RFC6864) *)
			packet.ipv4Hdr.flagsAndFragmentOffs := 0x0040; (* do not allow fragmentation *)
			packet.ipv4Hdr.ttl := Int8(IpTtl);
			packet.ipv4Hdr.protocol := protocol;
			packet.ipv4Hdr.checksum := Int16(0xd0f5); (*!TODO: compute checksum if the link device does not support IP checksum offload *)
			packet.ipv4Hdr.srcIpAddr := srcIpAddr.addr[0];
			packet.ipv4Hdr.dstIpAddr := dstIpAddr.addr[0];

			INC(packet.payloadOffs,SIZEOF(Ipv4Hdr));
		ELSE
			HALT(100);
		END;
	END SetIpPacket;

	(**
		Setup a UDP packet
	*)
	PROCEDURE SetUdpPacket*(
											packet: Packet;
											CONST srcMacAddr, dstMacAddr: MacAddr;
											CONST srcIpAddr, dstIpAddr: IpAddr;
											srcPort, dstPort: Int;
											udpDataLen: Int
											);
	BEGIN
		SetIpPacket(packet,srcMacAddr,dstMacAddr,srcIpAddr,dstIpAddr,ProtoUdp,udpDataLen+SIZEOF(UdpHdr));
		IF srcIpAddr.ver = 4 THEN
			packet.udpHdr := ADDRESSOF(packet.ipv4Hdr.verAndIhl) + SIZEOF(Ipv4Hdr);
			IF LittleEndianSystem THEN
				packet.udpHdr.length := EnetUtils.SwitchEndianness16(Int16(udpDataLen+SIZEOF(UdpHdr)));
			ELSE
				packet.udpHdr.length := Int16(udpDataLen+SIZEOF(UdpHdr));
			END;
		ELSE
			HALT(100);
		END;
		IF LittleEndianSystem THEN
			packet.udpHdr.srcPort := EnetUtils.SwitchEndianness16(Int16(srcPort));
			packet.udpHdr.dstPort := EnetUtils.SwitchEndianness16(Int16(dstPort));
		ELSE
			packet.udpHdr.srcPort := Int16(srcPort);
			packet.udpHdr.dstPort := Int16(dstPort);
		END;
		packet.udpHdr.checksum := 0;

		INC(packet.payloadOffs,SIZEOF(UdpHdr));
	END SetUdpPacket;

	(**
		Returns TRUE if an IP address belongs to the same subnetwork as the IP address of a given interface
	*)
	PROCEDURE IpAddrFromSameSubnet*(intf: Interface; CONST ipAddr: IpAddr): BOOLEAN;
	BEGIN
		IF ipAddr.ver = 4 THEN
			RETURN (S.VAL(Int32,S.VAL(SET,UInt(ipAddr.addr[0])) * S.VAL(SET,UInt(intf.ipv4SubnetMask.addr[0]))) = intf.ipv4Prefix)
				OR (ipAddr = BroadcastIpAddr);
		ELSIF ipAddr.ver = 6 THEN
			RETURN (S.VAL(Int32,S.VAL(SET,UInt(ipAddr.addr[0])) * S.VAL(SET,UInt(intf.ipv6SubnetMask.addr[0]))) = intf.ipv6Prefix.addr[0]) &
						(S.VAL(Int32,S.VAL(SET,UInt(ipAddr.addr[1])) * S.VAL(SET,UInt(intf.ipv6SubnetMask.addr[1]))) = intf.ipv6Prefix.addr[1]) &
						(S.VAL(Int32,S.VAL(SET,UInt(ipAddr.addr[2])) * S.VAL(SET,UInt(intf.ipv6SubnetMask.addr[2]))) = intf.ipv6Prefix.addr[2]) &
						(S.VAL(Int32,S.VAL(SET,UInt(ipAddr.addr[3])) * S.VAL(SET,UInt(intf.ipv6SubnetMask.addr[3]))) = intf.ipv6Prefix.addr[3])
		ELSE
			RETURN FALSE;
		END;
	END IpAddrFromSameSubnet;

	(**
		Returns TRUE if the two IP addresses are equal
	*)
	OPERATOR "="*(CONST ipAddr0, ipAddr1: IpAddr): BOOLEAN;
	BEGIN
		IF ipAddr0.ver = ipAddr1.ver THEN
			IF ipAddr0.ver = 4 THEN RETURN ipAddr0.addr[0] = ipAddr1.addr[0];
			ELSE RETURN (ipAddr0.addr[0] = ipAddr1.addr[0]) & (ipAddr0.addr[1] = ipAddr1.addr[1]) & (ipAddr0.addr[2] = ipAddr1.addr[2]) & (ipAddr0.addr[3] = ipAddr1.addr[3]);
			END;
		ELSE RETURN FALSE;
		END;
	END "=";

	(**
		Returns TRUE if the two IP addresses are not equal
	*)
	OPERATOR "#"*(CONST ipAddr0, ipAddr1: IpAddr): BOOLEAN;
	BEGIN
		RETURN ~(ipAddr0 = ipAddr1);
	END "#";

VAR
	NilMacAddr-: MacAddr; (** NIL MAC address *)
	BroadcastMacAddr-: MacAddr; (** broadcast MAC address *)
	NilIpAddr-: IpAddr; (** NIL IP address *)
	BroadcastIpAddr -: IpAddr; (** broadcast IPv4 address *)

	PROCEDURE InitMod;
	VAR i: Int;
	BEGIN
		Trace.string := EnetEnvironment.TraceString;
		EnetTiming.getTimeCounter := EnetEnvironment.GetTimeCounter;
		EnetTiming.fromMicro := EnetEnvironment.FromMicro;
		EnetTiming.fromMilli := EnetEnvironment.FromMilli;
		
		FOR i := 0 TO LEN(NilMacAddr.addr)-1 DO
			NilMacAddr.addr[i] := 0x00;
			BroadcastMacAddr.addr[i] := Int8(0xFF);
		END;

		NilIpAddr.addr[0] := 0x00;
		NilIpAddr.addr[1] := 0x00;
		NilIpAddr.addr[2] := 0x00;
		NilIpAddr.addr[3] := 0x00;
		NilIpAddr.ver := 0;

		ASSERT(StrToIpAddr("255.255.255.255", BroadcastIpAddr));
	END InitMod;

BEGIN
	InitMod;
END EnetBase.

