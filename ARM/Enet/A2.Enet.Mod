MODULE Enet; (** AUTHOR ""; PURPOSE ""; *)

IMPORT
	EnetBase, EnetTiming, EnetArp, EnetIcmp, EnetUdp, Objects, Locks, Kernel, Machine, Interfaces := EnetInterfaces, Trace;

CONST
	MaxNumInterfaces* = 2; (** maximal supported number of interfaces *)
	MaxArpCacheSize* = 256;

	UseSpinLocks* = TRUE; (** TRUE for forcing the use of spin locks *)

TYPE
	Int32 = EnetBase.Int32;
	Int16 = EnetBase.Int16;
	Int = EnetBase.Int;

	Interface* = OBJECT(EnetBase.Interface)
	VAR
		res: Int;
		alive: BOOLEAN;
		exited: BOOLEAN;
		waiting, waitingReq: BOOLEAN;

		lockDevRxFlag, lockDevTxFlag: BOOLEAN;
		lockDevRxPacketPoolFlag, lockDevTxPacketPoolFlag: BOOLEAN;
		lockTasksFlag: BOOLEAN;
		lockIpv4AddrCacheFlag, lockIpv6AddrCacheFlag: BOOLEAN;

		lockDevRx, lockDevTx: Locks.Lock;
		lockDevRxPacketPool, lockDevTxPacketPool: Locks.Lock;
		lockTasks: Locks.Lock;
		lockIpv4AddrCache, lockIpv6AddrCache: Locks.RWLock;

		PROCEDURE &InitInterface*(
											dev: EnetBase.LinkDevice;
											VAR res: Int
											);
		BEGIN
			IF ~Interfaces.InitInterface(SELF,dev,res) THEN RETURN; END;

			IF UseSpinLocks THEN SetupSpinLocks(FALSE); ELSE SetupLocks(FALSE); END;

			(*
				setup support of basic protocols
			*)
			EnetArp.Install(SELF);
			EnetIcmp.Install(SELF);
			EnetUdp.Install(SELF);

			IF UseSpinLocks THEN SetupSpinLocks(TRUE); ELSE SetupLocks(TRUE); END;

			(*
				setup interface-specific methods
			*)
			start := Start;
			stop := Stop;
			reset := Reset;
			finalize := Finalize;

			IF res = 0 THEN
				alive := TRUE;
				waitingReq := TRUE;
				waiting := TRUE;
				exited := FALSE;
			ELSE
				alive := FALSE;
			END;
		END InitInterface;

		PROCEDURE SetupLocks(ipAddrCacheOnly: BOOLEAN);
		BEGIN
			IF ~ipAddrCacheOnly THEN
				NEW(lockDevRx);
				NEW(lockDevTx);
				NEW(lockDevRxPacketPool);
				NEW(lockDevTxPacketPool);
				NEW(lockTasks);

				(*
					setup link device-specific locks
				*)
				dev.acquireRx := lockDevRx.Acquire;
				dev.releaseRx := lockDevRx.Release;

				dev.acquireTx := lockDevTx.Acquire;
				dev.releaseTx := lockDevTx.Release;

				dev.rxPacketPool.acquire := lockDevRxPacketPool.Acquire;
				dev.rxPacketPool.release := lockDevRxPacketPool.Release;

				dev.txPacketPool.acquire := lockDevTxPacketPool.Acquire;
				dev.txPacketPool.release := lockDevTxPacketPool.Release;

				(*
					setup locks for interface-specific tasks management
				*)
				acquireTasks := lockTasks.Acquire;
				releaseTasks := lockTasks.Release;
			ELSE
				NEW(lockIpv4AddrCache);
				NEW(lockIpv6AddrCache);

				(*
					setup locks for IP address resolution caches
				*)
				IF ipv4AddrCache # NIL THEN
					ipv4AddrCache.acquireWrite := lockIpv4AddrCache.AcquireWrite;
					ipv4AddrCache.releaseWrite := lockIpv4AddrCache.ReleaseWrite;
					ipv4AddrCache.acquireRead := lockIpv4AddrCache.AcquireRead;
					ipv4AddrCache.releaseRead := lockIpv4AddrCache.ReleaseRead;
				END;

				IF ipv6AddrCache # NIL THEN
					ipv6AddrCache.acquireWrite := lockIpv6AddrCache.AcquireWrite;
					ipv6AddrCache.releaseWrite := lockIpv6AddrCache.ReleaseWrite;
					ipv6AddrCache.acquireRead := lockIpv6AddrCache.AcquireRead;
					ipv6AddrCache.releaseRead := lockIpv6AddrCache.ReleaseRead;
				END;
			END;
		END SetupLocks;

		PROCEDURE SetupSpinLocks(ipAddrCacheOnly: BOOLEAN);
		BEGIN
			IF ~ipAddrCacheOnly THEN
				(*
					setup link device-specific locks
				*)
				dev.acquireRx := AcquireDevRx;
				dev.releaseRx := ReleaseDevRx;

				dev.acquireTx := AcquireDevTx;
				dev.releaseTx := ReleaseDevTx;

				dev.rxPacketPool.acquire := AcquireDevRxPacketPool;
				dev.rxPacketPool.release := ReleaseDevRxPacketPool;

				dev.txPacketPool.acquire := AcquireDevTxPacketPool;
				dev.txPacketPool.release := ReleaseDevTxPacketPool;

				(*
					setup locks for interface-specific tasks management
				*)
				acquireTasks := AcquireTasks;
				releaseTasks := ReleaseTasks;
			ELSE

				(*
					setup locks for IP address resolution caches
				*)
				IF ipv4AddrCache # NIL THEN
					ipv4AddrCache.acquireWrite := AcquireIpv4AddrCache;
					ipv4AddrCache.releaseWrite := ReleaseIpv4AddrCache;
					ipv4AddrCache.acquireRead := AcquireIpv4AddrCache;
					ipv4AddrCache.releaseRead := ReleaseIpv4AddrCache;
				END;

				IF ipv6AddrCache # NIL THEN
					ipv6AddrCache.acquireWrite := AcquireIpv6AddrCache;
					ipv6AddrCache.releaseWrite := ReleaseIpv6AddrCache;
					ipv6AddrCache.acquireRead := AcquireIpv6AddrCache;
					ipv6AddrCache.releaseRead := ReleaseIpv6AddrCache;
				END;
			END;
		END SetupSpinLocks;

		PROCEDURE AcquireDevRx; BEGIN Machine.AcquireObject(lockDevRxFlag); END AcquireDevRx;
		PROCEDURE ReleaseDevRx; BEGIN Machine.ReleaseObject(lockDevRxFlag); END ReleaseDevRx;
		PROCEDURE AcquireDevTx; BEGIN Machine.AcquireObject(lockDevTxFlag); END AcquireDevTx;
		PROCEDURE ReleaseDevTx; BEGIN Machine.ReleaseObject(lockDevTxFlag); END ReleaseDevTx;
		PROCEDURE AcquireDevRxPacketPool; BEGIN Machine.AcquireObject(lockDevRxPacketPoolFlag); END AcquireDevRxPacketPool;
		PROCEDURE ReleaseDevRxPacketPool; BEGIN Machine.ReleaseObject(lockDevRxPacketPoolFlag); END ReleaseDevRxPacketPool;
		PROCEDURE AcquireDevTxPacketPool; BEGIN Machine.AcquireObject(lockDevTxPacketPoolFlag); END AcquireDevTxPacketPool;
		PROCEDURE ReleaseDevTxPacketPool; BEGIN Machine.ReleaseObject(lockDevTxPacketPoolFlag); END ReleaseDevTxPacketPool;
		PROCEDURE AcquireTasks; BEGIN Machine.AcquireObject(lockTasksFlag); END AcquireTasks;
		PROCEDURE ReleaseTasks; BEGIN Machine.ReleaseObject(lockTasksFlag); END ReleaseTasks;
		PROCEDURE AcquireIpv4AddrCache; BEGIN Machine.AcquireObject(lockIpv4AddrCacheFlag); END AcquireIpv4AddrCache;
		PROCEDURE ReleaseIpv4AddrCache; BEGIN Machine.ReleaseObject(lockIpv4AddrCacheFlag); END ReleaseIpv4AddrCache;
		PROCEDURE AcquireIpv6AddrCache; BEGIN Machine.AcquireObject(lockIpv6AddrCacheFlag); END AcquireIpv6AddrCache;
		PROCEDURE ReleaseIpv6AddrCache; BEGIN Machine.ReleaseObject(lockIpv6AddrCacheFlag); END ReleaseIpv6AddrCache;

		PROCEDURE Start*(intf: EnetBase.Interface; VAR res: Int): BOOLEAN;
		BEGIN
			ASSERT(alive);

			IF dev.start(dev,res) THEN
				BEGIN{EXCLUSIVE}
					waitingReq := FALSE;
					waiting := FALSE;
				END;
				RETURN TRUE;
			ELSE
				RETURN FALSE;
			END;
		END Start;

		PROCEDURE Stop*(intf: EnetBase.Interface; VAR res: Int): BOOLEAN;
		VAR b: BOOLEAN;
		BEGIN
			ASSERT(alive);

			BEGIN{EXCLUSIVE}
				waitingReq := TRUE;
				AWAIT(waiting);
			END;
			RETURN dev.stop(dev,res);
		END Stop;

		PROCEDURE Reset*(intf: EnetBase.Interface; VAR res: Int): BOOLEAN;
		VAR b: BOOLEAN;
		BEGIN
			ASSERT(alive);

			BEGIN{EXCLUSIVE}
				waitingReq := TRUE;
				AWAIT(waiting);
			END;
			RETURN dev.reset(dev,res);
		END Reset;

		PROCEDURE Finalize(intf: EnetBase.Interface; VAR res: Int): BOOLEAN;
		VAR b: BOOLEAN;
		BEGIN
			b := Stop(SELF,res);
			alive := FALSE;
			BEGIN{EXCLUSIVE}
				AWAIT(exited);
			END;
			RETURN b;
		END Finalize;

	BEGIN{ACTIVE,PRIORITY(Objects.High)}

		WHILE alive DO
			IF ~waitingReq THEN

				IF ~Interfaces.Update(SELF,res) THEN
					BEGIN{EXCLUSIVE} waitingReq := TRUE; END;
				END;

			ELSE
				BEGIN{EXCLUSIVE}
					waiting := TRUE;
					AWAIT(~waiting OR ~alive)
				END;
			END;
		END;

		BEGIN{EXCLUSIVE}
			exited := TRUE;
		END;
	END Interface;

	PROCEDURE AcquireIntfsWrite(); BEGIN Machine.AcquireObject(lockIntfsFlag); END AcquireIntfsWrite;
	PROCEDURE ReleaseIntfsWrite(); BEGIN Machine.ReleaseObject(lockIntfsFlag); END ReleaseIntfsWrite;
	PROCEDURE AcquireIntfsRead(); BEGIN Machine.AcquireObject(lockIntfsFlag); END AcquireIntfsRead;
	PROCEDURE ReleaseIntfsRead(); BEGIN Machine.ReleaseObject(lockIntfsFlag); END ReleaseIntfsRead;

VAR
	lockIntfsFlag: BOOLEAN;
	lockIntfs: Locks.RWLock;
BEGIN
	IF UseSpinLocks THEN
		Interfaces.acquireIntfsWrite := AcquireIntfsWrite;
		Interfaces.releaseIntfsWrite := ReleaseIntfsWrite;

		Interfaces.acquireIntfsRead := AcquireIntfsRead;
		Interfaces.releaseIntfsRead := ReleaseIntfsRead;
	ELSE
		NEW(lockIntfs);
		Interfaces.acquireIntfsWrite := lockIntfs.AcquireWrite;
		Interfaces.releaseIntfsWrite := lockIntfs.ReleaseWrite;

		Interfaces.acquireIntfsRead := lockIntfs.AcquireRead;
		Interfaces.releaseIntfsRead := lockIntfs.ReleaseRead;
	END;
END Enet.
