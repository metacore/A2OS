MODULE SdDisks;
(**
	AUTHOR Timothée Martiel
	PURPOSE Disk driver for SD cards.
*)
IMPORT
	SYSTEM,
	Objects, Kernel, Plugins, Disks, Strings,
	Sd, SdEnvironment, KernelLog;

CONST
	NameBase		= "SD";

	BlockSize		= 512; (** Size of a SD block *)
	CacheSize		= 32; (** Number of entries in cache *)
	WBSize 			= 150; (** Number of entries in write buffer *)
	(*FlushPeriod	= 5 * 1000;*)

	EnableCache* = FALSE;

TYPE
	CacheEntry = RECORD
		buffer: POINTER TO ARRAY OF CHAR;
		ru: LONGINT;
		active: BOOLEAN;
	END;

	WriteBufferEntry = RECORD
		buffer: POINTER TO ARRAY OF CHAR;
		block, len: LONGINT;
	END;

	(**
		SD Card Disk Device
	*)
	Device * = OBJECT (Disks.Device)
	VAR
		card: Sd.Card;
		next: Device;
		timer: Kernel.Timer;
		cache: POINTER TO ARRAY OF CacheEntry;
		wbuffer: POINTER TO ARRAY OF WriteBufferEntry;
		bufferSize: LONGINT;
		head, size: LONGINT; (** Write buffer parameters *)
		stop: BOOLEAN;

		PROCEDURE & InitSdDevice (card: Sd.Card);
		VAR i: LONGINT;
		BEGIN
			SELF.card := card;
			blockSize := BlockSize;
			CASE card.sdStatus.speedClass OF
				 2, 4:
				 	IF card.csd.capacity > 1024*1024*1024 THEN
				 		bufferSize := 32 * 1024 DIV BlockSize
				 	ELSE
				 		bufferSize := 16 * 1024 DIV BlockSize
				 	END
				|6: bufferSize := 64 * 1024 DIV BlockSize
				|10: bufferSize := 512 * 1024 DIV BlockSize
			END;
			INCL(flags, Disks.Removable);
			IF EnableCache THEN
				NEW(cache, CacheSize);
				FOR i := 0 TO CacheSize - 1 DO NEW(cache[i].buffer, bufferSize * BlockSize) END;
				NEW(timer);
				NEW(wbuffer, WBSize);
				FOR i := 0 TO WBSize - 1 DO NEW(wbuffer[i].buffer, bufferSize * BlockSize) END;
			END;
		END InitSdDevice;

		PROCEDURE Transfer * (op, block, num: LONGINT; VAR data: ARRAY OF CHAR; ofs: LONGINT; VAR res: LONGINT);
		VAR
			size: LONGINT;

			PROCEDURE TransferCached();
			VAR
				s, ru, ruIdx, ruOfs: LONGINT;
				entry: POINTER {UNSAFE} TO CacheEntry;
				wbentry: POINTER {UNSAFE} TO WriteBufferEntry;
			BEGIN
				(* Caching *)
				WHILE size > 0 DO
					ru := block DIV bufferSize;
					ruOfs := block MOD bufferSize;
					s := MIN(size, (bufferSize - ruOfs) * BlockSize);
					ruIdx := ru MOD CacheSize;
					IF ~UpdateCacheEntry(ru, ruIdx, res) THEN RETURN END;
					entry := ADDRESSOF(cache[ruIdx]);
					IF op = Disks.Write THEN
						SYSTEM.MOVE(ADDRESSOF(data[ofs]), ADDRESSOF(entry.buffer[ruOfs * BlockSize]), s);
						(*IF ru = wbuffer[(head + SELF.size - 1) MOD WBSize].block DIV bufferSize THEN
							wbentry := ADDRESSOF(wbuffer[(head + SELF.size - 1) MOD WBSize]);
							SYSTEM.MOVE(ADDRESSOF(data[ofs]), ADDRESSOF(wbentry.buffer[ruOfs * BlockSize]), s);
							INC(wbentry.len, s);
						ELSE*)
							AWAIT(SELF.size < WBSize);
							wbentry := ADDRESSOF(wbuffer[(head + SELF.size) MOD WBSize]);
							SYSTEM.MOVE(ADDRESSOF(data[ofs]), ADDRESSOF(wbentry.buffer[0]), s);
							wbentry.block := block;
							wbentry.len := s;
							INC(SELF.size)
						(*END*)
						; INC(NbufferQueueSize, SELF.size); INC(NbufferQueueSamples);
					ELSE
						SYSTEM.MOVE(ADDRESSOF(entry.buffer[ruOfs * BlockSize]), ADDRESSOF(data[ofs]), s);
					END;
					DEC(size, s);
					INC(block, s DIV BlockSize);
					INC(ofs, s)
				END;
			END TransferCached;

			PROCEDURE TransferUncached();
			VAR
				ignore: BOOLEAN;
			BEGIN
				size := num * blockSize;
				CASE op OF
					 Disks.Write:
					 	ignore := Sd.Write(card, block, size, data, ofs, res)
					|Disks.Read:
						ignore := Sd.Read(card, block, size, data, ofs, res)
				END
			END TransferUncached;

		BEGIN {EXCLUSIVE}

			size := num * blockSize;

			IF EnableCache THEN
				TransferCached;
			ELSE
				TransferUncached;
			END;
		END Transfer;

		PROCEDURE GetSize * (VAR size, res: LONGINT);
		BEGIN
			size := LONGINT(card.csd.capacity);
			IF size < 0 THEN size := MAX(LONGINT) END;
			res := Disks.Ok
		END GetSize;

		PROCEDURE Handle * (VAR msg: Disks.Message;  VAR res: LONGINT);
		BEGIN
			res := 0;
			IF msg IS Disks.LockMsg THEN
				Sd.SetLedState(card.hc, TRUE)
			ELSIF msg IS Disks.UnlockMsg THEN
				Sd.SetLedState(card.hc, FALSE);
				IF EnableCache THEN Sync; END;
			ELSIF (msg IS Disks.EjectMsg) OR (msg IS Disks.SyncMsg) THEN
				IF EnableCache THEN Sync; END;
			END
		END Handle;

		(** Make sure that the RU ru is in cache entry idx *)
		PROCEDURE UpdateCacheEntry (ru, idx: LONGINT; VAR res: LONGINT): BOOLEAN;
		VAR entry: POINTER {UNSAFE} TO CacheEntry;
		BEGIN
			entry := ADDRESSOF(cache[idx]);
			IF ~entry.active OR (entry.ru # ru) THEN
				INC(NcacheMiss);
				IF entry.active THEN INC(NcacheEvict) END;
				(*IF entry.active & entry.mod THEN
					INC(NcacheWriteback);
					IF ~Sd.Write(card, entry.ru * bufferSize, bufferSize * BlockSize, entry.buffer^, 0, res) THEN RETURN FALSE END
				END;*)
				entry.active := TRUE;
				(*entry.mod := FALSE;*)
				entry.ru := ru;
				IF ~Sd.Read(card, ru * bufferSize, bufferSize * BlockSize, entry.buffer^, 0, res) THEN RETURN FALSE END
			ELSE
				INC(NcacheHits)
			END;
			RETURN TRUE
		END UpdateCacheEntry;

		(** Write back all modified cache entries to disk and invalidate all entries *)
		PROCEDURE Sync;
		VAR
			i, len, res, ofs: LONGINT;
			wbentry, wbnext: POINTER {UNSAFE} TO WriteBufferEntry;
			ignore: BOOLEAN;
		BEGIN {EXCLUSIVE}
			wbentry := ADDRESSOF(wbuffer[head MOD WBSize]);
			i := 1;
			len := wbentry.len;
			LOOP
				IF i = size THEN EXIT END;
				wbnext := ADDRESSOF(wbuffer[(head + i) MOD WBSize]);
				IF wbentry.block + len DIV BlockSize # wbnext.block THEN EXIT END;
				ofs := wbnext.block MOD bufferSize;
				SYSTEM.MOVE(ADDRESSOF(wbnext.buffer[ofs]), ADDRESSOF(wbentry.buffer[ofs]), wbnext.len);
				INC(len, wbnext.len);
				INC(i)
			END;
			ignore := Sd.Write(card, wbentry.block, len, wbentry.buffer^, 0, res);
			INC(head, i);
			DEC(size, i);
			INC(NbufferWrites);
			INC(NbufferSize, len)
		END Sync;

		PROCEDURE Stop;
		BEGIN {EXCLUSIVE}
			stop := TRUE
		END Stop;

	BEGIN {ACTIVE, PRIORITY(Objects.Normal)}
		LOOP
			BEGIN {EXCLUSIVE}
				AWAIT(stop OR (size > 0));
				IF stop THEN EXIT END;
			END;
			IF EnableCache THEN Sync; END;
		END;
		IF EnableCache THEN Sync; END;
	END Device;

	(** Handle SD Controller Events: create & register a new disk on card insertion, remove disk on card removal *)
	PROCEDURE HandleSdEvent * (card: Sd.Card; event: LONGINT);
	VAR
		disk, prev: Device;
		name, id: ARRAY 32 OF CHAR;
		result: LONGINT;
	BEGIN
		CASE event OF
			 Sd.OnInitialization:
				NEW(disk, card);
				Strings.IntToStr(diskId, id);
				name := NameBase;
				Strings.Append(name, id);
				disk.SetName(name);

				disk.desc := "SD";
				CASE card.scr.security OF
					 Sd.TypeNone, Sd.TypeSDSC:
					|Sd.TypeSDHC: Strings.Append(disk.desc, "HC")
					|Sd.TypeSDXC: Strings.Append(disk.desc, "XC")
				ELSE
					Strings.Append(disk.desc, "??");
					KernelLog.String("[SD] unknown card type: "); KernelLog.Int(card.scr.security, 0); KernelLog.Ln;
				END;
				Strings.Append(disk.desc, " card, v");
				CASE card.scr.version OF
					 Sd.Version1: Strings.Append(disk.desc, "1")
					|Sd.Version1p1: Strings.Append(disk.desc, "1.10")
					|Sd.Version2: Strings.Append(disk.desc, "2")
					|Sd.Version3: Strings.Append(disk.desc, "3")
					|Sd.Version4: Strings.Append(disk.desc, "4")
					|Sd.Version5: Strings.Append(disk.desc, "5")
					|Sd.Version6: Strings.Append(disk.desc, "6")
				ELSE
					Strings.Append(disk.desc, "?");
					KernelLog.String("[SD] unknown card version: "); KernelLog.Int(card.scr.version, 0); KernelLog.Ln;
				END;

				Disks.registry.Add(disk, result);

				IF result # Plugins.Ok THEN
					SdEnvironment.String("Error registering disk");
					SdEnvironment.Ln
				ELSE
					INC(diskId);
					disk.next := devices;
					devices := disk;
					SdEnvironment.String("Disk ");
					SdEnvironment.String(name);
					SdEnvironment.String(" is now available");
					SdEnvironment.Ln
				END

			|Sd.OnRemoval:
				ASSERT(devices # NIL);
				IF devices.card = card THEN
					devices.Stop;
					SdEnvironment.String("Removed disk ");
					SdEnvironment.String(devices.name);
					SdEnvironment.Ln;
					devices := devices.next
				ELSE
					disk := devices;
					WHILE (disk # NIL) & (disk.card # card) DO
						prev := disk;
						disk := disk.next
					END;
					ASSERT(disk # NIL);
					disk.Stop;
					SdEnvironment.String("Removed disk ");
					SdEnvironment.String(disk.name);
					SdEnvironment.Ln;
					prev.next := disk.next
				END;
		END
	END HandleSdEvent;

VAR
	devices: Device;
	diskId: LONGINT;

	(* Statistics *)
	NcacheHits *, NcacheMiss *, NcacheEvict *, NbufferWrites *, NbufferSize *, NbufferQueueSize *, NbufferQueueSamples *: LONGINT;

	PROCEDURE ResetStats *;
	BEGIN
		NcacheHits := 0;
		NcacheMiss := 0;
		NcacheEvict := 0;
		NbufferWrites := 0;
		NbufferSize := 0
	END ResetStats;
END SdDisks.
