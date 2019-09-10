(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE Caches; (** AUTHOR "pjm"; PURPOSE "Generic disk cache"; *)

IMPORT KernelLog, Objects, Disks;

(** Caching. *)

CONST
	LockedBit = 0;  DirtyBit = 1;	(* Buffer state flags *)

	CacheUpdateTime = 5*1000;	(* in ms *)

	Trace = TRUE;

TYPE
	Buffer* = OBJECT	(** all fields read-only *)
		VAR
			data*: POINTER TO ARRAY OF CHAR;
			dev*: Disks.Device;
			block*: SIGNED32;
			state: SET;
			nextHash, prevHash, nextLRU, prevLRU, nextDirty: Buffer;

		PROCEDURE &Init*(size: SIGNED32);
		BEGIN
			NEW(data, size)
		END Init;

	END Buffer;

	Cache* = OBJECT	(** all fields read-only *)
		VAR
			blockSize*: SIGNED32;
			hashTable: POINTER TO ARRAY OF Buffer;
			lru: Buffer;	(* LRU list of released buffers (only dirty buffers may be locked) *)
			lruClean: SIGNED32;	(* number of non-dirty buffers in lru *)
			syncNow: BOOLEAN;
			timer: Objects.Timer;

		(* exports: Acquire, Release, Synchronize *)

		(** Acquire a buffer for the specified device block.  If it is in the cache, its buffer is locked and
			returned with valid = TRUE, otherwise an unlocked non-dirty buffer is waited for, locked and returned
			with valid = FALSE. *)

		PROCEDURE Acquire*(dev: Disks.Device;  block: SIGNED32;  VAR buffer: Buffer;  VAR valid: BOOLEAN);
		VAR done: BOOLEAN;  buf: Buffer;  n, m: SIGNED32;
		BEGIN {EXCLUSIVE}
			ASSERT(dev # NIL);	(* NIL device is used for initialization *)
			REPEAT
				n := Hash(dev, block);  buf := hashTable[n];
				WHILE (buf # NIL) & ((buf.block # block) OR (buf.dev # dev)) DO
					buf := buf.nextHash
				END;
				IF buf # NIL THEN
					AWAIT(~(LockedBit IN buf.state));
						(* buf could have been re-used *)
					done := (buf.dev = dev) & (buf.block = block);
					valid := TRUE
				ELSE
					AWAIT(lruClean # 0);
					buf := lru.nextLRU;	(* find candidate and re-use *)
					WHILE DirtyBit IN buf.state DO syncNow := TRUE;  buf := buf.nextLRU END;
					ASSERT(buf # lru);	(* never re-use sentinel *)
					m := Hash(buf.dev, buf.block);
					IF m # n THEN MoveBuffer(buf, m, n) END;
					buf.dev := dev;  buf.block := block;
					done := TRUE;  valid := FALSE
				END
			UNTIL done;
			buf.prevLRU.nextLRU := buf.nextLRU;  buf.nextLRU.prevLRU := buf.prevLRU;	(* remove from lru *)
			IF ~(DirtyBit IN buf.state) THEN DEC(lruClean) END;
			INCL(buf.state, LockedBit);
			buffer := buf
		END Acquire;

		(** Release a buffer with valid data for use by another. *)

		PROCEDURE Release*(buffer: Buffer;  modified, written: BOOLEAN);
		BEGIN {EXCLUSIVE}
			EXCL(buffer.state, LockedBit);
			IF written THEN EXCL(buffer.state, DirtyBit);  INC(lruClean)
			ELSIF modified THEN INCL(buffer.state, DirtyBit)
			ELSIF ~(DirtyBit IN buffer.state) THEN INC(lruClean)
			ELSE (* skip *)
			END;
				(* Put(lru, buffer), and the buffer remains in the same hash list *)
			buffer.prevLRU := lru.prevLRU;  buffer.nextLRU := lru;
			buffer.prevLRU.nextLRU := buffer;  buffer.nextLRU.prevLRU := buffer
		END Release;

		(** Synchronize all momentarily dirty buffers that are not locked. *)

		PROCEDURE Synchronize*;
		VAR list, buf: Buffer; res: INTEGER; num, count: SIGNED32;
		BEGIN
			AcquireDirty(list); count := 0;
			WHILE list # NIL DO
				buf := list;  list := buf.nextDirty;  buf.nextDirty := NIL;
				ASSERT(blockSize MOD buf.dev.blockSize = 0);
				num := blockSize DIV buf.dev.blockSize;
(*
				KernelLog.Enter; KernelLog.String("Synchronize ");  KernelLog.String(buf.dev.name);  KernelLog.Char(" ");
				KernelLog.Int(buf.block, 1);  KernelLog.Char(" ");  KernelLog.Int(num, 1);  KernelLog.Exit;
*)
				buf.dev.Transfer(Disks.Write, buf.block, num, buf.data^, 0, res);
				IF res # Disks.Ok THEN ReportError(buf.dev, buf.block, num, res) END;
				ReleaseDirty(buf); INC(count)
			END;
			IF Trace & (count # 0) THEN
				KernelLog.Enter; KernelLog.String("Caches: "); KernelLog.String(buf.dev.name);
				KernelLog.Char(" "); KernelLog.Int(count, 1); KernelLog.Exit
			END
		END Synchronize;

		(* Auxiliary procedures *)

		(* Acquire a list of unlocked dirty buffers and lock them for synchronization. *)

		PROCEDURE AcquireDirty(VAR list: Buffer);
		VAR buf, tail: Buffer;
		BEGIN {EXCLUSIVE}
			list := NIL;  tail := NIL;  buf := lru.nextLRU;
			WHILE buf # lru DO
				IF buf.state * {LockedBit, DirtyBit} = {DirtyBit} THEN
					IF list = NIL THEN list := buf ELSE tail.nextDirty := buf END;
					tail := buf;  buf.nextDirty := NIL;
					INCL(buf.state, LockedBit)
					(* to preserve ordering, buf is not removed from lru *)
				END;
				buf := buf.nextLRU
			END
		END AcquireDirty;

		(* Release a dirty buffer on the lru list after synchronization. *)

		PROCEDURE ReleaseDirty(buffer: Buffer);
		BEGIN {EXCLUSIVE}
			ASSERT(buffer.state * {LockedBit, DirtyBit} = {LockedBit, DirtyBit});
			buffer.state := buffer.state - {LockedBit, DirtyBit};
			INC(lruClean)
		END ReleaseDirty;

		(* Wait until a periodic synchronize is due. *)

		PROCEDURE AwaitSync;
		BEGIN {EXCLUSIVE}
			AWAIT(syncNow);  syncNow := FALSE
		END AwaitSync;

		(* Hash function. *)

		PROCEDURE Hash(dev: Disks.Device;  block: SIGNED32): SIGNED32;
		BEGIN
			RETURN block MOD LEN(hashTable)(SIGNED32)	(* good candidate for inlining *)
		END Hash;

		(* Move buffer from one hash list to another. *)

		PROCEDURE MoveBuffer(buf: Buffer;  from, to: SIGNED32);
		BEGIN
				(* remove *)
			IF buf.prevHash # NIL THEN
				buf.prevHash.nextHash := buf.nextHash
			ELSE
				hashTable[from] := buf.nextHash
			END;
			IF buf.nextHash # NIL THEN buf.nextHash.prevHash := buf.prevHash END;
				(* add in front *)
			buf.prevHash := NIL;  buf.nextHash := hashTable[to];  hashTable[to] := buf;
			IF buf.nextHash # NIL THEN buf.nextHash.prevHash := buf END
		END MoveBuffer;

		PROCEDURE HandleTimeout;
		BEGIN {EXCLUSIVE}
			syncNow := TRUE;
			Objects.SetTimeout(timer, SELF.HandleTimeout, CacheUpdateTime)
		END HandleTimeout;

		(* Initialize the cache with specified size and hash size. *)

		PROCEDURE &Init*(blockSize, hashSize, cacheSize: SIGNED32);
		VAR buf: Buffer;  i, n: SIGNED32;
		BEGIN
			ASSERT(hashSize <= cacheSize);
			NEW(hashTable, hashSize);
			NEW(lru, 0);  lru.dev := NIL;  lru.block := -1;	(* sentinel *)
			lru.nextLRU := lru;  lru.prevLRU := lru;
			lruClean := cacheSize;  syncNow := FALSE;
			SELF.blockSize := blockSize;
			FOR i := 0 TO cacheSize-1 DO
				NEW(buf, blockSize);
				buf.dev := NIL;  buf.block := i;
				buf.state := {};  buf.nextDirty := NIL;
					(* add to hash table *)
				n := Hash(buf.dev, buf.block);	(* spread buffers of NIL device across hash table *)
				buf.prevHash := NIL;  buf.nextHash := hashTable[n];  hashTable[n] := buf;
				IF buf.nextHash # NIL THEN buf.nextHash.prevHash := buf END;
					(* Put(lru, buffer) *)
				buf.prevLRU := lru.prevLRU;  buf.nextLRU := lru;
				buf.prevLRU.nextLRU := buf;  buf.nextLRU.prevLRU := buf
			END;
			NEW(timer); Objects.SetTimeout(timer, SELF.HandleTimeout, CacheUpdateTime)
		END Init;

	BEGIN {ACTIVE, SAFE}	(* cache periodically synchronizes automatically *)
		LOOP AwaitSync;  Synchronize END
	END Cache;

(* Report an error during asynchronous disk access. *)

PROCEDURE ReportError(dev: Disks.Device; block, num: SIGNED32; res: INTEGER);
BEGIN
	KernelLog.Enter; KernelLog.String("Caches: Error "); KernelLog.Int(res, 1);
	KernelLog.String(" on disk "); KernelLog.String(dev.name); KernelLog.Int(num, 1);
	KernelLog.String(" blocks at "); KernelLog.Int(block, 1); KernelLog.Exit
END ReportError;

END Caches.
