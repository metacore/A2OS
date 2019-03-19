MODULE UsbVarTdAlloc; (** AUTHOR "Timothée Martiel"; PURPOSE "Variable-size data-structure allocator for EHCI."; *)

IMPORT Machine;

CONST
	AllocSize = 1024 * 1024;
	AllocAlign = 1024 * 1024;

TYPE
	(**
		Buffer descriptor
	 *)
	TdBuffer = OBJECT
	VAR
		buffer: POINTER TO ARRAY OF CHAR;
		used: POINTER TO ARRAY OF SET;
		ofs: LONGINT;
		next: TdBuffer;

		PROCEDURE & Init (block: LONGINT);
		VAR
			bitmaskSize: LONGINT;
		BEGIN
			NEW(buffer, AllocSize + AllocAlign);
			ofs := AllocAlign - ADDRESSOF(buffer[0]) MOD AllocAlign;
			bitmaskSize := AllocSize DIV (block * SetSize);
			NEW(used, bitmaskSize)
		END Init;

		PROCEDURE Used(block: LONGINT): BOOLEAN;
		BEGIN
			RETURN (block MOD SetSize) IN used[block DIV SetSize];
		END Used;

		PROCEDURE SetUsed(block: LONGINT);
		BEGIN
			INCL(used[block DIV SetSize], block MOD SetSize);
		END SetUsed;

		(* faster version of SetUsed for blocks
		PROCEDURE SetUsedR(from, to: LONGINT);
		VAR startSet, stopSet, startBit, stopBit: LONGINT;
		BEGIN
			IF to < from THEN RETURN END;
			startBit := from MOD SetSize;
			stopBit := to MOD SetSize;
			startSet := from DIV SetSize;
			stopSet := to DIV SetSize;
			IF startSet < stopSet THEN
				used[startSet] := used[startSet] + {startBit .. MAX(SET)};
				INC(startSet);
				WHILE startSet < stopSet DO
					used[startSet] := {MIN(SET)..MAX(SET)};
					INC(startSet);
				END;
				used[stopSet] := used[stopSet] + {MIN(SET) .. stopBit};
			ELSE
				used[stopSet] := used[stopSet] + {startBit .. stopBit};
			END;
		END SetUsedR;
		*)

		PROCEDURE SetFree(block: LONGINT);
		BEGIN
			EXCL(used[block DIV SetSize], block MOD SetSize);
		END SetFree;

		(* faster version of SetFree for blocks
		PROCEDURE SetFreeR(from, to: LONGINT);
		VAR startSet, stopSet, startBit, stopBit: LONGINT;
		BEGIN
			IF to < from THEN RETURN END;
			startBit := from MOD SetSize;
			stopBit := to MOD SetSize;
			startSet := from DIV SetSize;
			stopSet := to DIV SetSize;
			IF startSet < stopSet THEN
				used[startSet] := used[startSet] - {startBit .. MAX(SET)};
				INC(startSet);
				WHILE startSet < stopSet DO
					used[startSet] := {};
					INC(startSet);
				END;
				used[stopSet] := used[stopSet] - {MIN(SET) .. stopBit};
			ELSE
				used[stopSet] := used[stopSet] - {startBit .. stopBit};
			END;
		END SetFreeR;
		*)


	END TdBuffer;

	(**
		Allocator.

		The allocator is created with a page size and a block size. It can then allocate memory blocks with a granularity of the block size.
		Each allocated block is guaranteed not to cross a page boundary.

		Allocated blocks must be freed manually.
	*)
	CONST SetSize = SIZEOF(SET) * 8;

	TYPE Allocator * = OBJECT
	VAR
		tdBuffers: TdBuffer;
		pageSize, blockSize, bitmaskSize: LONGINT;

		PROCEDURE & Setup * (pageSize, blockSize: LONGINT);
		BEGIN
			ASSERT(SetSize = 32);
			ASSERT((AllocSize MOD blockSize) MOD SetSize = 0);
			SELF.pageSize := pageSize;
			SELF.blockSize := blockSize;
			bitmaskSize := AllocSize DIV (blockSize * SetSize)
		END Setup;

		(** Allocate memory for a TD or a QH of the given size. The size must be a multiple of 32. *)
		PROCEDURE Allocate * (size: SIZE): ADDRESS;
		VAR
			buf: TdBuffer;
			start, pos, count: LONGINT;
			adr: ADDRESS;

			(** Allocate a new TD buffer and mark as used the last 32-byte block before a 4kB page boundary. *)
			PROCEDURE AllocateBuffer;
			VAR
				buf: TdBuffer;
				count, mod: LONGINT;
			BEGIN
				(* No buffer found: allocate a new one *)
				NEW(buf, blockSize);
				(*NEW(buf.buffer, AllocSize + AllocAlign);
				NEW(buf.used, bitmaskSize);*)

				buf.next := tdBuffers;
				tdBuffers := buf;
				count := 0;
				mod := ADDRESSOF(buf.buffer[0]) MOD AllocAlign;
				IF mod # 0 THEN
					buf.ofs := AllocAlign - mod
				END;

				Machine.DisableDCacheRange(ADDRESSOF(buf.buffer[buf.ofs]), AllocSize);

				(* Remove last 32-byte block before a 4kB page boundary from free blocks *)
				LOOP
					IF count >= AllocSize DIV blockSize THEN EXIT END;
					IF (ADDRESSOF(buf.buffer[buf.ofs + count * blockSize]) MOD pageSize) = pageSize - blockSize THEN
						buf.SetUsed(count);
					END;
					INC(count)
				END;
			END AllocateBuffer;


		BEGIN {EXCLUSIVE}
			ASSERT(size MOD blockSize = 0);
			size := size DIV blockSize;

			buf := tdBuffers;
			LOOP
				IF buf = NIL THEN
					AllocateBuffer;
					buf := tdBuffers;
					ASSERT(buf # NIL)
				END;
				count := 0;
				pos := 0;
				start := pos;
				WHILE (count < size) & (pos < bitmaskSize) DO
					IF buf.Used(pos) THEN
						count := 0;
						start := pos + 1;
					ELSE
						INC(count);
					END;
					INC(pos);
				END;

				IF count = size THEN EXIT END;
				buf := buf.next
			END;

			ASSERT(buf # NIL);

			adr := ADDRESSOF(buf.buffer[buf.ofs + start*blockSize]);

			(* faster version:
			buf.SetUsedR(start, start+count-1);
			*)
			WHILE(count > 0) DO
				ASSERT(~buf.Used(start));
				buf.SetUsed(start);
				INC(start); DEC(count);
			END;
			Machine.Fill32(adr, size * blockSize, 0);
			RETURN adr;
		END Allocate;

		(** Marks a TD as free, so that its memory can be used again *)
		PROCEDURE Free * (td: ADDRESS; size: SIZE);
		VAR
			buf: TdBuffer;
			adr: ADDRESS;
			slot: LONGINT;
		BEGIN {EXCLUSIVE}
			ASSERT(size MOD blockSize = 0);
			size := size DIV blockSize;

			buf := tdBuffers;
			LOOP
				IF buf = NIL THEN EXIT END;
				adr := ADDRESSOF(buf.buffer[buf.ofs]);
				IF (adr <= td) & (td < adr + AllocSize) THEN EXIT END;
				buf := buf.next
			END;
			ASSERT(buf # NIL); (* Not a TD *)

			slot := (td - adr) DIV blockSize;
			(* faster version:
			buf.SetFreeR(slot, slot+size-1);
			*)
			WHILE (size > 0) DO
				ASSERT(buf.Used(slot));
				buf.SetFree(slot);
				INC(slot); DEC(size);
			END;
		END Free;
	END Allocator;


	StaticAllocator * = OBJECT
	VAR
		buffers: TdBuffer;
		size: LONGINT;

		PROCEDURE & Setup * (allocSize: LONGINT);
		BEGIN
			size := allocSize
		END Setup;

		PROCEDURE Allocate * (): ADDRESS;
		BEGIN {EXCLUSIVE}
		END Allocate;

		PROCEDURE Free * (td: ADDRESS);
		BEGIN {EXCLUSIVE}
		END Free;
	END StaticAllocator;
(*VAR
	padding: POINTER TO ARRAY OF CHAR;
BEGIN
	NEW(padding, 1024 * 1024)*)
END UsbVarTdAlloc.

(* test module, uncomment for running a randomized test

MODULE TestUsbVarTdAlloc; (** AUTHOR ""; PURPOSE ""; *)

IMPORT UsbVarTdAlloc, Random;

PROCEDURE Test*;
VAR allocator: UsbVarTdAlloc.Allocator; adr: POINTER TO ARRAY OF ADDRESS;
gen: Random.Generator; i,j, k: LONGINT; size: POINTER TO ARRAY OF SIZE;
BEGIN
	NEW(allocator, 4096, 32);
	NEW(gen);
	NEW(adr, 1024); NEW(size, 1024);
	FOR j := 0 TO 100 DO
		FOR i := 0 TO LEN(adr)-1  DO
			size[i] := 32+gen.Dice(120)*32;
			adr[i] := allocator.Allocate(size[i]);
			ASSERT(adr[i] MOD 32 = 0);
			ASSERT(adr[i] DIV 4096 = (adr[i] + size[i]) DIV 4096);
			FOR k := 0 TO i-1 DO
				ASSERT(adr[k] # adr[i]);
			END;
		END;
		FOR i := 0 TO LEN(adr)-1 DO
			allocator.Free(adr[i], size[i]);
		END;
		TRACE(j);
	END;
	TRACE("done");
END Test;



END TestUsbVarTdAlloc.

System.Free TestUsbVarTdAlloc UsbVarTdAlloc ~

TestUsbVarTdAlloc.Test ~

*)
