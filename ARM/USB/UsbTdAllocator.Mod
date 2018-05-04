(**
 * UsbTdAllocator
 *
 * This module provides common TD allocation code for UsbOhci and UsbUhci.
 * In those USB 1.0 controllers, all data structures are 16-byte aligned and their size
 * is less than or equal to 16 bytes.
 *)
MODULE UsbTdAllocator; (** AUTHOR "Timothée Martiel"; PURPOSE "Common TD allocation code for UsbUhci and UsbOhci"; *)
CONST
	(** Size of each individual buffer. Must be a multiple of BlockSize * 32. *)
	TdBufferSize = 4096;
	(** Size of an allocation block. *)
	BlockSize = 16;
	BitmaskSize = TdBufferSize DIV (BlockSize * 32);

TYPE
	TdBuffer = POINTER TO RECORD
		buffer: ARRAY TdBufferSize OF CHAR;
		used: ARRAY BitmaskSize OF SET;
		next: TdBuffer;
	END;

	Allocator * = OBJECT
	VAR
		buffers: TdBuffer;

		PROCEDURE Allocate * (): ADDRESS;
			VAR
				buf: TdBuffer;
				count, tdIn, tdOut: LONGINT;

				(** Allocate a new TD buffer and mark as used the last 32-byte block before a 4kB page boundary. *)
				PROCEDURE AllocateBuffer;
				VAR
					buf: TdBuffer;
					count: LONGINT;
				BEGIN
					(* No buffer found: allocate a new one *)
					NEW(buf);
					buf.next := buffers;
					buffers := buf;
					count := 0;
				END AllocateBuffer;

			BEGIN
				(* Find a buffer with enough room. *)
				buf := buffers;
				LOOP
					IF buf = NIL THEN
						AllocateBuffer;
						buf := buffers;
						ASSERT(buf # NIL)
					END;
					count := 0;
					tdOut := 0;
					FOR tdOut := 0 TO BitmaskSize - 1 DO
						FOR tdIn := 0 TO 31 DO
							IF ~(tdIn IN buf.used[tdOut]) THEN
								INCL(buf.used[tdOut], tdIn);
								RETURN ADDRESSOF(buf.buffer[(tdOut * 32 + tdIn) * BlockSize])
							END
						END
					END;
					buf := buf.next
				END;
				(* We should not get to this point *)
				ASSERT(buf # NIL);
		END Allocate;

		PROCEDURE Free * (td: ADDRESS(*; size: LONGINT*));
			VAR
				buf: TdBuffer;
				adr: ADDRESS;
				slot, tdIn, tdOut: LONGINT;
			BEGIN
				(*ASSERT(size MOD BlockSize = 0);*)
				buf := buffers;
				LOOP
					IF buf = NIL THEN EXIT END;
					adr := ADDRESSOF(buf.buffer[0]);
					IF (adr <= td) & (td <= adr + TdBufferSize) THEN EXIT END;
					buf := buf.next
				END;
				ASSERT(buf # NIL); (* Not a TD *)

				slot := (td - adr) DIV BlockSize;
				tdOut := slot DIV 32;
				tdIn := slot MOD 32;
				(*FOR i := 0 TO (size DIV BlockSize) - 1 DO
					IF tdIn + i < 32 THEN*)
						ASSERT(tdIn (*+ i*) IN buf.used[tdOut]);
						EXCL(buf.used[tdOut], tdIn (*+ i*))
					(*ELSE
						ASSERT(tdIn + i - 32 IN buf.used[tdOut + 1]);
						EXCL(buf.used[tdOut + 1], tdIn + i - 32)
					END
				END;*)
		END Free;
	END Allocator;
END UsbTdAllocator.
