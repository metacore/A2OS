MODULE Enet;

IMPORT
	EnetBase, Interfaces := EnetInterfaces, EnetArp, EnetIcmp, EnetUdp;

CONST
	MaxNumInterfaces* = 2; (** maximal supported number of interfaces *)
	MaxArpCacheSize* = 256;

TYPE
	Int32 = EnetBase.Int32;
	Int16 = EnetBase.Int16;
	Int = EnetBase.Int;
	ResultCode = EnetBase.ResultCode;

	Interface* = EnetBase.Interface;

VAR

	PROCEDURE InitInterface*(
										intf: Interface;
										dev: EnetBase.LinkDevice;
										VAR res: ResultCode
										);
	BEGIN
		IF ~Interfaces.InitInterface(intf,dev,res) THEN RETURN; END;

		(*
			setup link device-specific locks
		*)
		intf.dev.acquireRx := AcquireDevRx;
		intf.dev.releaseRx := ReleaseDevRx;

		intf.dev.acquireTx := AcquireDevTx;
		intf.dev.releaseTx := ReleaseDevTx;

		intf.dev.rxPacketPool.acquire := AcquireDevRxPacketPool;
		intf.dev.rxPacketPool.release := ReleaseDevRxPacketPool;

		intf.dev.txPacketPool.acquire := AcquireDevTxPacketPool;
		intf.dev.txPacketPool.release := ReleaseDevTxPacketPool;

		(*
			setup locks for interface-specific tasks management
		*)
		intf.acquireTasks := AcquireTasks;
		intf.releaseTasks := ReleaseTasks;

		EnetArp.Install(intf);
		EnetIcmp.Install(intf);
		EnetUdp.Install(intf);

		(*
			setup locks for IP address resolution caches
		*)
		IF intf.ipv4AddrCache # NIL THEN
			intf.ipv4AddrCache.acquireWrite := AcquireIpv4AddrCache;
			intf.ipv4AddrCache.releaseWrite := ReleaseIpv4AddrCache;
			intf.ipv4AddrCache.acquireRead := AcquireIpv4AddrCache;
			intf.ipv4AddrCache.releaseRead := ReleaseIpv4AddrCache;
		END;

		IF intf.ipv6AddrCache # NIL THEN
			intf.ipv6AddrCache.acquireWrite := AcquireIpv6AddrCache;
			intf.ipv6AddrCache.releaseWrite := ReleaseIpv6AddrCache;
			intf.ipv6AddrCache.acquireRead := AcquireIpv6AddrCache;
			intf.ipv6AddrCache.releaseRead := ReleaseIpv6AddrCache;
		END;

		intf.start := Start;
		intf.stop := Stop;
		intf.reset := Reset;
		intf.finalize := Finalize;
	END InitInterface;

	(**
		Update the state of all available network interfaces
	*)
	PROCEDURE Update*;
	VAR i: Int; res: ResultCode;
	BEGIN
		FOR i := 0 TO Interfaces.numIntfs -1 DO
			IF ~Interfaces.Update(Interfaces.intfs[i],res) THEN
			END;
		END;
	END Update;

	PROCEDURE Start(intf: EnetBase.Interface; VAR res: ResultCode): BOOLEAN;
	BEGIN
		RETURN intf.dev.start(intf.dev,res);
	END Start;

	PROCEDURE Stop(intf: EnetBase.Interface; VAR res: ResultCode): BOOLEAN;
	BEGIN
		RETURN intf.dev.stop(intf.dev,res);
	END Stop;

	PROCEDURE Reset(intf: EnetBase.Interface; VAR res: ResultCode): BOOLEAN;
	BEGIN
		RETURN intf.dev.reset(intf.dev,res);
	END Reset;

	PROCEDURE Finalize(intf: EnetBase.Interface; VAR res: ResultCode): BOOLEAN;
	BEGIN
		IF ~intf.dev.stop(intf.dev,res) THEN END;
		RETURN intf.dev.finalize(intf.dev,res);
	END Finalize;

	PROCEDURE AcquireDevRx; BEGIN HALT(101); END AcquireDevRx;
	PROCEDURE ReleaseDevRx; BEGIN HALT(102); END ReleaseDevRx;
	PROCEDURE AcquireDevTx; BEGIN HALT(103); END AcquireDevTx;
	PROCEDURE ReleaseDevTx; BEGIN HALT(104); END ReleaseDevTx;
	PROCEDURE AcquireDevRxPacketPool; BEGIN HALT(105); END AcquireDevRxPacketPool;
	PROCEDURE ReleaseDevRxPacketPool; BEGIN HALT(106); END ReleaseDevRxPacketPool;
	PROCEDURE AcquireDevTxPacketPool; BEGIN HALT(107); END AcquireDevTxPacketPool;
	PROCEDURE ReleaseDevTxPacketPool; BEGIN HALT(108); END ReleaseDevTxPacketPool;
	PROCEDURE AcquireTasks; BEGIN HALT(109); END AcquireTasks;
	PROCEDURE ReleaseTasks; BEGIN HALT(110); END ReleaseTasks;
	PROCEDURE AcquireIpv4AddrCache; BEGIN HALT(111); END AcquireIpv4AddrCache;
	PROCEDURE ReleaseIpv4AddrCache; BEGIN HALT(112); END ReleaseIpv4AddrCache;
	PROCEDURE AcquireIpv6AddrCache; BEGIN HALT(113); END AcquireIpv6AddrCache;
	PROCEDURE ReleaseIpv6AddrCache; BEGIN HALT(114); END ReleaseIpv6AddrCache;

	PROCEDURE AcquireIntfsWrite(); BEGIN HALT(115); END AcquireIntfsWrite;
	PROCEDURE ReleaseIntfsWrite(); BEGIN HALT(116); END ReleaseIntfsWrite;
	PROCEDURE AcquireIntfsRead(); BEGIN HALT(117); END AcquireIntfsRead;
	PROCEDURE ReleaseIntfsRead(); BEGIN HALT(118); END ReleaseIntfsRead;

END Enet.
