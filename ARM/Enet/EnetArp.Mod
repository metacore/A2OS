MODULE EnetArp;
(**
	AUTHOR: Alexey Morozov, HighDim GmbH, 2015
	PURPOSE: Ethernet networking stack, ARP protocol
*)

IMPORT
	SYSTEM, EnetBase, EnetTiming, Interfaces := EnetInterfaces, Trace := EnetTrace;

CONST
	ArpHwTypeEth* = 0x0100; (** ARP hardware type *)

	(**
		ARP operation types
	*)
	ArpOpRequest* = 0x0100;
	ArpOpResponse* = 0x0200;

	ArpCacheSize* = 256;

	SubnetMaskC = 0x00FFFFFF; (* mask for class C subnetwork (255.255.255.0) *)

	UpdateIntervalMs = 10000; (* update ARP cache state interval in ms *)
	ArpEntryRequestTimeoutMs = 100; (* ARP entry request timeout in ms *)
	ArpEntryExpireTimeoutMs = 20*60*1000; (* default ARP entry expiration timeout in ms *)

TYPE
	Int32 = EnetBase.Int32;
	Int16 = EnetBase.Int16;
	Int = EnetBase.Int;
	ResultCode = EnetBase.ResultCode;

	(**
		ARP cache
	*)
	ArpCache* = POINTER TO ArpCacheDesc;
	ArpCacheDesc* = RECORD(EnetBase.IpAddrCacheDesc)
		entries*: ARRAY ArpCacheSize OF ArpEntry;
		requested: ArpEntry; (* linked list of entries being under resolution *)
	END;

	(**
		Entry of Address Resolution Protocol (ARP) cache
	*)
	ArpEntry* = POINTER TO ArpEntryDesc;
	ArpEntryDesc* = RECORD(EnetBase.IpAddrCacheEntryDesc)
		static*: BOOLEAN; (** TRUE for static entries not to be removed automatically *)
		resolved*: BOOLEAN; (** becomes TRUE after the IPv4 address of the entry has been resolved *)
		requested*: BOOLEAN; (** TRUE if the entry is in the requested list *)
		timestamp*: EnetTiming.Time; (* time when the entry was registered as resolved *)

		completionHandler: EnetBase.TaskHandler; (* completion handler from the user *)
		timeoutHandler: EnetBase.TaskHandler; (* request timeout handler *)

		prevReq, nextReq: ArpEntry; (* for managing a linked list of requested entries *)
		cache: ArpCache;
	END;

	(*
		Initialize ARP cache
	*)
	PROCEDURE InitArpCache(cache: ArpCache; intf: EnetBase.Interface);
	VAR
		i: Int;
		entry: ArpEntry;
	BEGIN
		ASSERT(cache # NIL);

		FOR i := 0 TO ArpCacheSize-1 DO
			NEW(entry);
			entry.ipAddr.addr[0] := 0;
			entry.ipAddr.ver := 4;
			entry.macAddr := EnetBase.NilMacAddr;
			entry.static := FALSE;
			entry.resolved := FALSE;
			entry.requested := FALSE;
			entry.timestamp := 0;
			entry.cache := cache;
			NEW(entry.timeoutHandler);

			cache.entries[i] := entry;
		END;

		cache.requested := NIL;

		cache.cleanCache := CleanArpCache;
		cache.addStaticEntry := AddStaticEntry;
		cache.enumerateEntries := EnumerateEntries;
		cache.intf := intf;
	END InitArpCache;

	PROCEDURE IsSubnetMaskC(CONST subnetMask: EnetBase.IpAddr): BOOLEAN;
	BEGIN
		RETURN SYSTEM.MSK(subnetMask.addr[0],SubnetMaskC) = SubnetMaskC;
	END IsSubnetMaskC;

	(*
		Get a free ARP entry given an IP address
	*)
	PROCEDURE GetFreeEntry(cache: ArpCache; ipv4Addr: Int32): ArpEntry;
	VAR
		i: Int;
		entry: ArpEntry;
	BEGIN
		IF IsSubnetMaskC(cache.intf.ipv4SubnetMask) THEN
			i := (ipv4Addr DIV 1000000H) MOD 100H; (* the most significant byte *)
			entry := cache.entries[i];
			ASSERT(~entry.static & ~entry.resolved & ~entry.requested);
			entry.ipAddr.addr[0] := ipv4Addr;
			RETURN entry;
		ELSE
			HALT(100);
		END;
	END GetFreeEntry;

	(*
		Find a resolved ARP cache entry given an IPv4 address
	*)
	PROCEDURE FindResolvedEntryByIpAddr(cache: ArpCache; ipv4Addr: Int32): ArpEntry;
	VAR
		i: Int;
		entry: ArpEntry;
	BEGIN
		IF IsSubnetMaskC(cache.intf.ipv4SubnetMask) THEN
			i := (ipv4Addr DIV 1000000H) MOD 100H; (* the most significant byte *)
			entry := cache.entries[i];
			IF entry.resolved THEN RETURN entry; ELSE RETURN NIL; END;
		ELSE
			HALT(100);
		END;
	END FindResolvedEntryByIpAddr;

	(*
		Find a requested ARP entry given an IPv4 address
	*)
	PROCEDURE FindRequestedEntryByIpAddr(cache: ArpCache; ipv4Addr: Int32; removeIfResolved: BOOLEAN): ArpEntry;
	VAR entry, prev: ArpEntry;
	BEGIN
		entry := cache.requested;
		WHILE (entry # NIL) & (entry.ipAddr.addr[0] # ipv4Addr) DO
			prev := entry;
			entry := prev.nextReq;
		END;
		IF removeIfResolved & (entry # NIL) THEN
			RemoveRequestedEntry(cache,entry);
		END;
		RETURN entry;
	END FindRequestedEntryByIpAddr;

	(*
		Add an ARP entry to the requested list
	*)
	PROCEDURE AddRequestedEntry(cache: ArpCache; entry: ArpEntry);
	BEGIN
		entry.requested := TRUE;
		entry.prevReq := NIL;
		IF cache.requested = NIL THEN
			entry.nextReq := NIL;
			cache.requested := entry;
		ELSE
			entry.nextReq := cache.requested;
			cache.requested.prevReq := entry;
			cache.requested := entry;
		END;
	END AddRequestedEntry;

	(*
		Remove an ARP entry from the requested list
	*)
	PROCEDURE RemoveRequestedEntry(cache: ArpCache; entry: ArpEntry);
	BEGIN
		entry.requested := FALSE;
		IF entry.prevReq # NIL THEN entry.prevReq.nextReq := entry.nextReq;
		ELSIF entry = cache.requested THEN cache.requested := entry.nextReq; END;
		IF entry.nextReq # NIL THEN entry.nextReq.prevReq := entry.prevReq; END;
		entry.nextReq := NIL;
		entry.prevReq := NIL;
	END RemoveRequestedEntry;

	(*
		Make an ARP announcement on a given network interface
	*)
	PROCEDURE ArpAnnouncement(intf: EnetBase.Interface; VAR res: ResultCode): BOOLEAN;
	VAR packet: EnetBase.Packet;
	BEGIN
		IF ~Interfaces.GetTxPacket(intf,packet) THEN
			res := EnetBase.ErrTxPacketPoolEmpty;
			RETURN FALSE;
		END;

		(* setup Ethernet frame header *)
		packet.ethFrameHdr.dstMacAddr := EnetBase.BroadcastMacAddr;
		packet.ethFrameHdr.srcMacAddr := intf.dev.macAddr;
		packet.ethFrameHdr.etherType := EnetBase.EtherTypeArp;

		(* setup ARP header *)
		packet.arpHdr.hwType := ArpHwTypeEth;
		packet.arpHdr.protoType := EnetBase.EtherTypeIpv4;
		packet.arpHdr.hwAddrLen := 6;
		packet.arpHdr.protoAddrLen := 4;
		packet.arpHdr.operation := ArpOpRequest;
		packet.arpHdr.srcMacAddr := intf.dev.macAddr;
		packet.arpHdr.srcIpAddr := intf.ipv4Addr.addr[0];
		packet.arpHdr.dstMacAddr := EnetBase.BroadcastMacAddr;
		packet.arpHdr.dstIpAddr := intf.ipv4Addr.addr[0];

		packet.dataLen := SIZEOF(EnetBase.EthFrameHdr) + SIZEOF(EnetBase.ArpHdr);

		RETURN Interfaces.SendPacket(intf,packet,{},NIL,res);
	END ArpAnnouncement;

	(**
		Send an ARP request for resolving a given IP address
	*)
	PROCEDURE ArpRequest(intf: EnetBase.Interface; CONST ipv4AddrToResolve: Int32; VAR res: ResultCode): BOOLEAN;
	VAR
		packet: EnetBase.Packet;
	BEGIN
		IF ~Interfaces.GetTxPacket(intf,packet) THEN
			res := EnetBase.ErrTxPacketPoolEmpty;
			RETURN FALSE;
		END;

		(* setup Ethernet frame header *)
		packet.ethFrameHdr.dstMacAddr := EnetBase.BroadcastMacAddr;
		packet.ethFrameHdr.srcMacAddr := intf.dev.macAddr;
		packet.ethFrameHdr.etherType := EnetBase.EtherTypeArp;

		(* setup ARP header *)
		packet.arpHdr.hwType := ArpHwTypeEth;
		packet.arpHdr.protoType := EnetBase.EtherTypeIpv4;
		packet.arpHdr.hwAddrLen := 6;
		packet.arpHdr.protoAddrLen := 4;
		packet.arpHdr.operation := ArpOpRequest;
		packet.arpHdr.srcMacAddr := intf.dev.macAddr;
		packet.arpHdr.srcIpAddr := intf.ipv4Addr.addr[0];
		packet.arpHdr.dstMacAddr := EnetBase.NilMacAddr;
		packet.arpHdr.dstIpAddr := ipv4AddrToResolve;

		packet.dataLen := SIZEOF(EnetBase.EthFrameHdr) + SIZEOF(EnetBase.ArpHdr);

		RETURN Interfaces.SendPacket(intf,packet,{},NIL,res);
	END ArpRequest;

	(*
		Handle an ARP packet
	*)
	PROCEDURE HandleArpPacket(intf: EnetBase.Interface; packet: EnetBase.Packet; flags: SET);
	VAR
		cache: ArpCache;
		entry: ArpEntry;
		srcIpAddr: Int32;
		res: ResultCode;
		completionHandler, timeoutHandler: EnetBase.TaskHandler;
	BEGIN
		IF (packet.arpHdr.hwType = ArpHwTypeEth) & (packet.arpHdr.protoType = EnetBase.EtherTypeIpv4) & (packet.arpHdr.dstIpAddr = intf.ipv4Addr.addr[0]) THEN
			IF packet.arpHdr.operation = ArpOpRequest THEN
				packet.arpHdr.operation := ArpOpResponse;
				packet.arpHdr.dstMacAddr := packet.arpHdr.srcMacAddr;
				packet.arpHdr.dstIpAddr := packet.arpHdr.srcIpAddr;
				packet.arpHdr.srcMacAddr := intf.dev.macAddr;
				packet.arpHdr.srcIpAddr := intf.ipv4Addr.addr[0];
				IF ~Interfaces.ReplyEth(intf,packet,{},NIL,res) THEN
				END;
			ELSIF packet.arpHdr.operation = ArpOpResponse THEN

				cache := intf.ipv4AddrCache(ArpCache);
				IF EnetBase.ThreadSafe THEN cache.acquireWrite; END;

				(* find the corresponding ARP entry request *)
				srcIpAddr := packet.arpHdr.srcIpAddr;
				entry := FindRequestedEntryByIpAddr(cache,srcIpAddr,TRUE);
				IF entry # NIL THEN (*! account for cases when the requested entry was removed earlier due to timeout expiration *)
					entry.macAddr := packet.arpHdr.srcMacAddr;
					entry.timestamp := EnetTiming.getTimeCounter();
					entry.resolved := TRUE;
					EnetBase.RemoveTask(intf,entry.timeoutHandler); (* remove timeout handler from the interface non-periodic task list *)
					completionHandler := entry.completionHandler;
					entry.completionHandler := NIL;
				END;

				IF EnetBase.ThreadSafe THEN cache.releaseWrite; END;

				(* notify the user about the operation completion *)
				IF completionHandler # NIL THEN
					completionHandler.res := 0;
					IF completionHandler.handle # NIL THEN
						completionHandler.handle(completionHandler);
					END;
				END;
			END;
		END;
	END HandleArpPacket;

	(*
		Request resolution of a new ARP cache entry
	*)
	PROCEDURE ArpEntryRequest(
											intf: EnetBase.Interface;
											cache: ArpCache;
											entry: ArpEntry;
											completionHandler: EnetBase.TaskHandler;
											handleTimeout: BOOLEAN;
											VAR res: ResultCode): BOOLEAN;
	VAR
		i: Int;
		b: BOOLEAN;
	BEGIN
		IF ArpRequest(intf,entry.ipAddr.addr[0],res) THEN

			AddRequestedEntry(cache,entry); (* add the requested entry to the linked list of requested entries *)
			entry.completionHandler := completionHandler;
			IF handleTimeout THEN
				entry.timeoutHandler.handle := HandleArpEntryRequestTimeout;
				entry.timeoutHandler.param := entry;
				EnetBase.ScheduleTask(intf,entry.timeoutHandler,FALSE,entryRequestTimeout);
			END;

			res := EnetBase.OpInProgress;

			RETURN TRUE;
		ELSE
			RETURN FALSE;
		END;
	END ArpEntryRequest;

	(*
		Resolve IPv4 address, thread-safe
	*)
	PROCEDURE ResolveIpv4Addr(intf: EnetBase.Interface; CONST ipAddr: EnetBase.IpAddr; VAR macAddr: EnetBase.MacAddr; completionHandler: EnetBase.TaskHandler; VAR res: ResultCode): BOOLEAN;
	VAR
		cache: ArpCache;
		entry: ArpEntry;
		b: BOOLEAN;
	BEGIN
		ASSERT(ipAddr.ver = 4);

		(* Broadcast address is always resolved to broadcast MAC *)
		IF ipAddr = EnetBase.BroadcastIpAddr THEN
			macAddr := EnetBase.BroadcastMacAddr;
			res := 0;
			
			IF (completionHandler # NIL) & (completionHandler.handle # NIL) THEN
				completionHandler.res := 0;
				EnetBase.ScheduleTask(intf, completionHandler, FALSE, 1)
			END;
			RETURN TRUE
		END;

		cache := intf.ipv4AddrCache(ArpCache);

		IF EnetBase.ThreadSafe THEN cache.acquireRead; END;

		entry := FindResolvedEntryByIpAddr(cache,ipAddr.addr[0]);
		IF entry # NIL THEN
			macAddr := entry.macAddr;

			IF EnetBase.ThreadSafe THEN cache.releaseRead; END;

			res := 0;
			b := TRUE;

			IF (completionHandler # NIL) & (completionHandler.handle # NIL) THEN
				completionHandler.res := 0;
				EnetBase.ScheduleTask(intf, completionHandler, FALSE, 1)
			END;
		ELSE
			IF EnetBase.ThreadSafe THEN cache.releaseRead; END;

			IF completionHandler # NIL THEN

				completionHandler.res := EnetBase.OpInProgress;

				IF EnetBase.ThreadSafe THEN cache.acquireWrite; END;

				entry := FindRequestedEntryByIpAddr(cache,ipAddr.addr[0],FALSE);
				IF entry # NIL THEN (*! the specified IP address is being already in resolution *)
					EnetBase.LinkTaskHandlers(entry.completionHandler,completionHandler);
				ELSE (* send an ARP request *)
					entry := GetFreeEntry(cache,ipAddr.addr[0]);
					ASSERT(entry # NIL);
					b := ArpEntryRequest(intf,cache,entry,completionHandler,TRUE,res);
				END;

				IF EnetBase.ThreadSafe THEN cache.releaseWrite; END;
			ELSE
				b := FALSE;
				res := EnetBase.ErrUnresolvedAddr;
			END;
		END;

		RETURN b;
	END ResolveIpv4Addr;

	PROCEDURE CleanArpCache(cache: EnetBase.IpAddrCache; cleanStatic: BOOLEAN);
	VAR
		i: Int;
		entry: ArpEntry;
	BEGIN
		WITH cache : ArpCache DO
			IF EnetBase.ThreadSafe THEN cache.acquireWrite; END;
			FOR i := 0 TO ArpCacheSize-1 DO
				entry := cache.entries[i];
				IF ~entry.requested & (cleanStatic OR ~entry.static) THEN
					entry.resolved := FALSE;
				END;
			END;
			IF EnetBase.ThreadSafe THEN cache.releaseWrite; END;
		END;
	END CleanArpCache;

	(*
		Add a static entry to the address resolution table
	*)
	PROCEDURE AddStaticEntry(cache: EnetBase.IpAddrCache; CONST ipAddr: EnetBase.IpAddr; CONST macAddr: EnetBase.MacAddr; VAR res: ResultCode): BOOLEAN;
	VAR
		i: Int;
		entry: ArpEntry;
	BEGIN
		ASSERT(ipAddr.ver = 4);

		WITH cache : ArpCache DO

			IF IsSubnetMaskC(cache.intf.ipv4SubnetMask) THEN

				IF EnetBase.ThreadSafe THEN cache.acquireWrite; END;

				i := (ipAddr.addr[0] DIV 1000000H) MOD 100H; (* the most significant byte *)

				entry := cache.entries[i];
				entry.ipAddr := ipAddr;
				entry.macAddr := macAddr;
				entry.static := TRUE;
				entry.resolved := TRUE;
				entry.requested := FALSE;
				entry.timestamp := 0;
				entry.prevReq := NIL;
				entry.nextReq := NIL;

				IF EnetBase.ThreadSafe THEN cache.releaseWrite; END;

				res := 0;
				RETURN TRUE;
			ELSE
				HALT(100);
			END;
		END;
	END AddStaticEntry;

	(*
		Enumerate all resolved entries of the address resolution table
	*)
	PROCEDURE EnumerateEntries(cache: EnetBase.IpAddrCache; enumerator: PROCEDURE{DELEGATE}(entry: EnetBase.IpAddrCacheEntry));
	VAR
		i: Int;
		entry: ArpEntry;
	BEGIN
		ASSERT(enumerator # NIL);
		WITH cache : ArpCache DO
			IF EnetBase.ThreadSafe THEN cache.acquireRead; END;
			FOR i := 0 TO ArpCacheSize-1 DO
				entry := cache.entries[i];
				IF entry.resolved THEN
					enumerator(entry);
				END;
			END;
			IF EnetBase.ThreadSafe THEN cache.releaseRead; END;
		END;
	END EnumerateEntries;

	PROCEDURE ShowEntry(entry: ArpEntry);
	VAR j: Int;
	BEGIN
		Trace.StringLn("ipv4Addr=0x" & Trace.Hx(entry.ipAddr.addr[0],8));
		Trace.String("macAddr=" & Trace.Hx(entry.macAddr.addr[0],2));
		FOR j := 1 TO LEN(entry.macAddr.addr)-1 DO
			Trace.String(":" & Trace.Hx(entry.macAddr.addr[j],2));
		END;
		Trace.StringLn("");
		Trace.StringLn("static=" & entry.static);
		Trace.StringLn("resolved=" & entry.resolved);
		Trace.StringLn("requested=" & entry.requested);
		Trace.StringLn("timestamp=" & entry.timestamp);
	END ShowEntry;

	PROCEDURE ShowArpCache*(cache: ArpCache);
	VAR
		i, j, n: Int;
		entry: ArpEntry;
	BEGIN
		IF EnetBase.ThreadSafe THEN cache.acquireRead; END;

		Trace.StringLn("resolved entries: ");
		n := 0;
		FOR i := 0 TO LEN(cache.entries)-1 DO
			entry := cache.entries[i];
			IF entry.resolved THEN
				Trace.StringLn("#" & n);
				ShowEntry(entry);
				INC(n);
			END;
		END;

		IF n = 0 THEN
			Trace.StringLn("none");
		END;

		Trace.StringLn("requested entries: ");
		n := 0;
		entry := cache.requested;
		WHILE entry # NIL DO
			Trace.StringLn("#" & n);
			ShowEntry(entry);
			INC(n);
			entry := entry.nextReq;
		END;

		IF EnetBase.ThreadSafe THEN cache.releaseRead; END;

		IF n = 0 THEN
			Trace.StringLn("none");
		END;
	END ShowArpCache;

	PROCEDURE HandleArpEntryRequestTimeout(handler: EnetBase.TaskHandler);
	VAR
		intf: EnetBase.Interface;
		cache: ArpCache;
		requested: ArpEntry;
		completionHandler, tmp: EnetBase.TaskHandler;
	BEGIN
		requested := handler.param(ArpEntry);
		cache := requested.cache;
		intf := cache.intf;
		IF EnetBase.ThreadSafe THEN cache.acquireWrite; END;
		completionHandler := requested.completionHandler;
		RemoveRequestedEntry(cache,requested);
		IF EnetBase.ThreadSafe THEN cache.releaseWrite; END;

		(* inform the user about timeout expiration *)
		WHILE completionHandler # NIL DO
			completionHandler.res := EnetBase.ErrTimeoutExpired;
			IF completionHandler.handle # NIL THEN
				completionHandler.handle(completionHandler);
			END;
			tmp := completionHandler.next;
			completionHandler.next := NIL; (*! unlink handlers *)
			completionHandler := tmp;
		END;
	END HandleArpEntryRequestTimeout;

	PROCEDURE Update(handler: EnetBase.TaskHandler);
	VAR
		intf: EnetBase.Interface;
		cache: ArpCache;
		entry: ArpEntry;
		t: EnetTiming.Time;
		i: Int; res: ResultCode;
		requestedEntryUpdate: BOOLEAN;
	BEGIN
		intf := handler.param(EnetBase.Interface);
		cache := intf.ipv4AddrCache(ArpCache);

		IF EnetBase.ThreadSafe THEN cache.acquireWrite; END;

		(*
			update expired dynamic entries
		*)
		t := EnetTiming.getTimeCounter();
		requestedEntryUpdate := FALSE;
		FOR i := 0 TO ArpCacheSize-1 DO
			entry := cache.entries[i];
			IF ~requestedEntryUpdate & ~entry.static & entry.resolved & ~entry.requested & (t - entry.timestamp >= entryExpireTimeout) THEN
				IF ArpEntryRequest(intf,cache,entry,NIL,FALSE,res) THEN (*! do not schedule timeout task - no task scheduling is allowed in a task handler *)
					requestedEntryUpdate := TRUE; (*! request updating of one entry at a time to avoid ARP message storm *)

					Trace.StringLn("requested update of an ARP entry: ");
					ShowEntry(entry);

				ELSE
					entry.resolved := FALSE;
					ASSERT(~entry.requested);
				END;
			ELSIF ~entry.static & entry.resolved & entry.requested & (t - entry.timestamp >= entryRequestTimeout) THEN
				RemoveRequestedEntry(cache,entry);
				entry.resolved := FALSE;
			END;
		END;

		IF EnetBase.ThreadSafe THEN cache.releaseWrite; END;

	END Update;

VAR
	entryRequestTimeout: EnetTiming.Time;
	entryExpireTimeout: EnetTiming.Time;

	PROCEDURE Install*(intf: EnetBase.Interface);
	VAR
		cache: ArpCache;
		updateTask: EnetBase.TaskHandler;
	BEGIN

		IF entryRequestTimeout = 0 THEN
			entryRequestTimeout := EnetTiming.fromMilli(ArpEntryRequestTimeoutMs);
			entryExpireTimeout := EnetTiming.fromMilli(ArpEntryExpireTimeoutMs);
		END;

		NEW(cache);
		InitArpCache(cache,intf);
		intf.ipv4AddrResolve := ResolveIpv4Addr;
		intf.ipv4AddrCache := cache;

		EnetBase.SetEthFrameHandler(intf,EnetBase.EtherTypeArp,HandleArpPacket);

		NEW(updateTask);
		updateTask.res := 0;
		updateTask.handle := Update;
		updateTask.param := intf;

		EnetBase.ScheduleTask(intf,updateTask,TRUE,EnetTiming.fromMilli(UpdateIntervalMs));
	END Install;

END EnetArp.
