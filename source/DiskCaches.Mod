MODULE DiskCaches; (* Simple (disk) cache, fof 2018 *)
IMPORT SYSTEM, Disks;

	TYPE TransferProcedure = PROCEDURE {DELEGATE} (op,block,num: LONGINT; VAR data: ARRAY OF CHAR; ofs: LONGINT; VAR res: WORD);

	CONST BlockSize = 512;
	CONST NumberCacheLines = 128;

	TYPE
		CacheLine = RECORD
			globalIndex: SIZE;
			data: POINTER TO ARRAY OF CHAR;
		END;

	TYPE
	
	(* Yet very simple disk cache. 
		- synchronous
		- One-way associative
		- Write-through
	*)
	Cache* = OBJECT
	VAR
		lines: ARRAY NumberCacheLines OF CacheLine;
		blocksPerCacheLine: LONGINT;
		transfer: TransferProcedure;

		PROCEDURE &Init*(transfer: TransferProcedure; blocksPerCacheLine = 32: LONGINT);
		VAR i: SIZE;
		BEGIN
			SELF.transfer := transfer;
			SELF.blocksPerCacheLine := blocksPerCacheLine;
			FOR i := 0 TO LEN(lines)-1 DO
				lines[i].globalIndex := -1;
				NEW(lines[i].data,blocksPerCacheLine * BlockSize );
			END;
		END Init;

		(* LONGINTs for compatibility -- should be largely replaced by SIZEs ! *)
		PROCEDURE Transfer* (op: LONGINT; block, num: LONGINT; VAR data: ARRAY OF CHAR; ofs: LONGINT; VAR res: WORD);
		VAR globalIndex, lineIndex, lineOfs, lineFirstBlock, lineBlocks: LONGINT;
		BEGIN
			WHILE num > 0 DO
				globalIndex := block DIV blocksPerCacheLine; (* global index *)
				lineIndex := globalIndex MOD NumberCacheLines; (* (local) line index *)
				lineOfs := block MOD blocksPerCacheLine; (* line offset in blocks *)
				lineFirstBlock := block - lineOfs;
				lineBlocks := MIN(num, blocksPerCacheLine - lineOfs); (* chunk size in bytes *)

				IF (lines[lineIndex].globalIndex # globalIndex) THEN (* cacheline present *)
					IF op = Disks.Read THEN (* read to cache *)
						transfer(op, lineFirstBlock, blocksPerCacheLine, lines[lineIndex].data^, 0, res); (* assumes that lineFirstBlock is a valid block *)
						lines[lineIndex].globalIndex := globalIndex;
					END;
				ELSIF op = Disks.Write THEN (* write to present cacheline *)
					SYSTEM.MOVE(ADDRESS OF data[ofs], ADDRESS OF lines[lineIndex].data[lineOfs*BlockSize], lineBlocks*BlockSize);
				END;

				IF op = Disks.Write THEN (* always write through*)
					transfer(op, block, lineBlocks, data, ofs, res);
				ELSE (* read from cache *)
					SYSTEM.MOVE(ADDRESS OF lines[lineIndex].data[lineOfs*BlockSize], ADDRESS OF data[ofs], lineBlocks*BlockSize);
				END;
				DEC(num, lineBlocks);
				INC(block, lineBlocks);
				INC(ofs, lineBlocks*BlockSize);
			END;

		END Transfer;

	END Cache;

END DiskCaches.

(** USAGE PATTERN: 

	VirtualDisk = OBJECT(Disks.Device)
	VAR
		...
		cache: DiskCaches.Cache;

		PROCEDURE TransferX*(op, block, num: LONGINT; VAR data: ARRAY OF CHAR; ofs: LONGINT; VAR res: WORD);
		BEGIN
			.... OLD TRANSFER CODE
		END TransferX;
		
		PROCEDURE Transfer(op, block, num: LONGINT; VAR data: ARRAY OF CHAR; ofs: LONGINT; VAR res: WORD);
		BEGIN{EXCLUSIVE}
			cache.Transfer(op,block,num,data,ofs,res) 
		END Transfer;

		....		

		PROCEDURE &Init(CONST name : ARRAY OF CHAR; blockSize, cyls, hds, spt : LONGINT);
		BEGIN
			NEW(cache, TransferX);
			....
		END Init;

	END VirtualDisk;

**)
