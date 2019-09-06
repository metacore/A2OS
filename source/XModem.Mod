MODULE XModem;	(** AUTHOR "be"; PURPOSE "XModem protocol"; *)

(* following the "Modem Protocol Documentation by Ward Christensen, 1/1/1982 *)

IMPORT SYSTEM, Kernel, Streams, KernelLog;

CONST
	DebugS = FALSE;	(* debug sender *)
	DebugR = FALSE;	(* debug receiver *)

	(* result codes *)
	Ok* = 0;
	Timeout* = 1;
	Error* = 2;

	(* states *)
	SInit = 00X;
	SData = 01X;
	SEOT = 02X;
	RInitCRC = 03X;
	RInitChksum = 04X;
	RData = 05X;
	Abort = 06X;
	Exit = 07X;

	(* Timeouts ([ms]) *)
	SenderInitialTimeout = 60000;
	SenderACKTimeout = 60000;
	ReceiverInitTimeout = 3000;
	ReceiverDataTimeout = 1000;
	PurgeTimeout = 1000;

	MaxRetries = 10;
	MaxCRCThreshold = 3;

	HeaderSize = 3;
	BlockSize = 128;
	ChksumSize = 1;
	CRCSize = 2;
	PacketSizeChksum = HeaderSize + BlockSize + ChksumSize;
	PacketSizeCRC = HeaderSize + BlockSize + CRCSize;
	MaxPacketSize = PacketSizeCRC;

	(* symbols *)
	SOH = 01X;
	EOT = 04X;
	ACK = 06X;
	NAK = 15X;

TYPE
	XModem* = OBJECT
		VAR
			state: CHAR;	(* current state *)
			rx: Streams.Reader;	(* input channel *)
			tx: Streams.Writer;	(* output channel *)
			crc: BOOLEAN;	(* TRUE iff in CRC mode, FALSE iff in checksum mode *)
			packetSize: LONGINT;	(* size of a packet, including header & checksum/CRC. Initialized by SendInit/ReceiveInit *)
			retries: LONGINT;	(* # of retries *)
			blockIndex: LONGINT;	(* # of block *)
			msg: ARRAY 256 OF CHAR;	(* error message *)

		PROCEDURE &InitXModem*(rx: Streams.Reader; tx: Streams.Writer);
		BEGIN
			SELF.rx := rx; SELF.tx := tx
		END InitXModem;

		PROCEDURE Get(r: Streams.Reader; timeout: LONGINT; VAR ch: CHAR): LONGINT;
		VAR milliTimer : Kernel.MilliTimer;
		BEGIN
			IF (r.Available() = 0) THEN
				Kernel.SetTimer(milliTimer, timeout);
				REPEAT
				UNTIL (r.Available() > 0) OR Kernel.Expired(milliTimer);
				IF (r.Available() = 0) THEN
					ch := 0X; RETURN Timeout
				END
			END;
			ch := r.Get();
			RETURN Ok
		END Get;

		PROCEDURE Peek(r: Streams.Reader; timeout: LONGINT; VAR ch: CHAR): LONGINT;
		VAR milliTimer : Kernel.MilliTimer;
		BEGIN
			IF (r.Available() = 0) THEN
				Kernel.SetTimer(milliTimer, timeout);
				REPEAT
				UNTIL (r.Available() > 0) OR Kernel.Expired(milliTimer);
				IF (r.Available() = 0) THEN
					ch := 0X; RETURN Timeout
				END
			END;
			ch := r.Peek();
			RETURN Ok
		END Peek;

		PROCEDURE Purge(r: Streams.Reader);
		VAR ch: CHAR;
		BEGIN
			REPEAT UNTIL Get(r, PurgeTimeout, ch) = Timeout
		END Purge;

		PROCEDURE CalcCheckSum(VAR buffer: ARRAY OF CHAR; ofs, len: LONGINT): CHAR;
		VAR i, chksum: LONGINT;
		BEGIN
			chksum := 0;
			FOR i := 0 TO len-1 DO chksum := chksum + ORD(buffer[ofs+i]) END;
			RETURN CHR(chksum MOD 100H)
		END CalcCheckSum;

		PROCEDURE CalcCRC(VAR buffer: ARRAY OF CHAR; ofs, len: LONGINT): LONGINT;
		VAR i, k, crc: LONGINT;
		BEGIN
			crc := 0;
			FOR i := 0 TO len-1 DO
				crc := LONGINT(SET(crc) / SET(ORD(buffer[ofs+i])*100H));
				FOR k := 0 TO 7 DO
					IF (15 IN SET(crc)) THEN
						crc := LONGINT(SET(crc*2) /SET(1021H))
					ELSE
						crc := crc*2
					END
				END
			END;
			RETURN crc MOD 10000H
		END CalcCRC;

		PROCEDURE GetErrorMessage*(VAR string: ARRAY OF CHAR);
		BEGIN
			COPY(msg, string)
		END GetErrorMessage;
	END XModem;

	XMSender* = OBJECT(XModem)
		VAR
			data: Streams.Reader;
			buffer: ARRAY MaxPacketSize OF CHAR;
			resend: BOOLEAN;

		PROCEDURE &Init*(data, rx: Streams.Reader; tx: Streams.Writer);
		BEGIN
			InitXModem(rx, tx); SELF.data := data; state := SInit;
			blockIndex := 1; retries := 0; resend := FALSE
		END Init;

		PROCEDURE GetData(VAR buffer: ARRAY OF CHAR; ofs, len: LONGINT);
		VAR i: LONGINT;
		BEGIN
			i := 0;
			WHILE (data.Available() > 0) & (i < len) DO
				buffer[ofs+i] := data.Get(); INC(i)
			END;
			WHILE (i < len) DO buffer[ofs+i] := 0X; INC(i) END
		END GetData;

		PROCEDURE SetHeader(VAR buf: ARRAY OF CHAR; index: LONGINT);
		BEGIN
			ASSERT(index < 100H);
			buf[0] := SOH;
			buf[1] := CHR(index);
			buf[2] := CHR(255-index)
		END SetHeader;

		PROCEDURE SendInit;
		VAR res: WORD; ch: CHAR;
		BEGIN
			IF DebugS THEN
				KernelLog.String("SendInit:"); KernelLog.Ln; KernelLog.String("  waiting for 'C'/NAK...")
			END;
			res := Get(rx, SenderInitialTimeout, ch);

			IF (res = Ok) THEN
				IF DebugS THEN KernelLog.String("got "); KernelLog.Hex(ORD(ch), -2); KernelLog.Char("X"); KernelLog.Ln END;
				IF ((ch = NAK) OR (ch = "C")) THEN
					crc := (ch = "C");
					IF crc THEN packetSize := PacketSizeCRC ELSE packetSize := PacketSizeChksum END;
					IF DebugS THEN
						IF crc THEN KernelLog.String("  CRC") ELSE KernelLog.String("  checksum") END;
						KernelLog.String(" mode; new state = SData"); KernelLog.Ln
					END;
					state := SData
				ELSE
					INC(retries); (* state stays the same (SInit) *)
					COPY("SendInit: wrong reply", msg);
					IF DebugS THEN KernelLog.String("  retries = "); KernelLog.Int(retries, 0); KernelLog.Ln END
				END
			ELSE (* timeout *)
				COPY("SendInit timeout", msg);
				IF DebugS THEN KernelLog.String("  new state = Abort"); KernelLog.Ln END;
				state := Abort
			END
		END SendInit;

		PROCEDURE SendData;
		VAR c, res: LONGINT; ch: CHAR;
		BEGIN
			IF DebugS THEN KernelLog.String("SendData:"); KernelLog.Ln END;
			(* send block *)
			IF ~resend THEN
				SetHeader(buffer, blockIndex MOD 100H);
				GetData(buffer, HeaderSize, BlockSize);
				IF crc THEN
					c := CalcCRC(buffer, HeaderSize, BlockSize);
					buffer[HeaderSize+BlockSize] := CHR(c DIV 100H);
					buffer[HeaderSize+BlockSize+1] := CHR(c MOD 100H);
				ELSE
					buffer[HeaderSize+BlockSize] := CalcCheckSum(buffer, HeaderSize, BlockSize)
				END
			ELSE resend := FALSE
			END;
			IF DebugS THEN KernelLog.String("  sending "); KernelLog.Int(packetSize, 0); KernelLog.String(" bytes...") END;
			tx.Bytes(buffer, 0, packetSize); tx.Update;
			WHILE (rx.res = 0) & (rx.Available() > 0) DO ch := rx.Get() END;	(* toss any characters immediately upon completing sending a block *)
			IF DebugS THEN KernelLog.String("done."); KernelLog.Ln; KernelLog.String("  waiting for ACK...") END;

			(* wait for ACK *)
			res := Get(rx, SenderACKTimeout, ch);
			IF (res = Ok) THEN
				IF (ch = ACK) THEN
					IF DebugS THEN KernelLog.String("ok."); KernelLog.Ln END;
					INC(blockIndex);
					IF (data.Available() = 0) THEN state := SEOT END;	(* ELSE state stays the same (SData) *)
					retries := 0	(* temp...*)
				ELSE
					IF DebugS THEN KernelLog.String("no (got "); KernelLog.Hex(ORD(ch),-2); KernelLog.String("X)"); KernelLog.Ln END;
					COPY("SendData: no ACK", msg);
					INC(retries);	(* state stays the same (SData) *)
					resend := TRUE	(* send same data again *)
				END
			ELSE (* timeout *)
				COPY("SendData: timeout", msg);
				IF DebugS THEN KernelLog.String("  timeout; res = "); KernelLog.Int(res, 0); KernelLog.Ln END;
				state := Abort
			END
		END SendData;

		PROCEDURE SendEOT;
		VAR res: WORD; ch: CHAR;
		BEGIN
			(* send EOT *)
			tx.Char(EOT); tx.Update;

			(* wait for ACK *)
			res := Get(rx, SenderACKTimeout, ch);
			IF (res = Ok) THEN
				IF (ch = ACK) THEN state := Exit
				ELSE
					COPY("SendEOT: no ACK", msg);
					INC(retries) (* state stays the same (SEOT) *)
				END
			ELSE (* timeout *)
				COPY("SendEOT: timeout", msg);
				state := Abort
			END
		END SendEOT;

		(* completely receiver-driven *)
		PROCEDURE Send*(): LONGINT;
		BEGIN
			WHILE (state # Abort) & (state # Exit) & (retries < MaxRetries) DO
				CASE state OF
				| SInit: SendInit
				| SData: SendData
				| SEOT: SendEOT
				END
			END;
			IF (state = Exit) THEN RETURN Ok
			ELSE RETURN Error
			END
		END Send;
	END XMSender;

	XMReceiver* = OBJECT(XModem)
		VAR
			data: Streams.Writer;
			crcThreshold: LONGINT;

		PROCEDURE &Init*(data: Streams.Writer; rx: Streams.Reader; tx: Streams.Writer);
		BEGIN
			InitXModem(rx, tx); SELF.data := data; state := RInitCRC;
			blockIndex := 1; retries := 0; crcThreshold := 0
		END Init;

		PROCEDURE PutData(VAR buffer: ARRAY OF CHAR; ofs, len: LONGINT);
		BEGIN
			data.Bytes(buffer, ofs, len)
		END PutData;

		PROCEDURE GetHeader(VAR buf: ARRAY OF CHAR): LONGINT;
		VAR index: LONGINT;
		BEGIN
			IF (buf[0] = SOH) THEN
				index := ORD(buf[1]);
				IF (index # 255-ORD(buf[2])) THEN index := -1 END
			ELSE
				index := -1
			END;
			RETURN index
		END GetHeader;

		PROCEDURE ReceiveInitCRC;
		VAR res: WORD; ch: CHAR;
		BEGIN
			IF DebugR THEN
				KernelLog.String("ReceiveInitCRC:"); KernelLog.Ln; KernelLog.String("  sending 'C'..."); KernelLog.Ln
			END;
			packetSize := PacketSizeCRC;
			(* send "C" *)
			crc := TRUE;
			tx.Char("C"); tx.Update;

			(* wait for ACK *)
			IF DebugR THEN KernelLog.String("  waiting for reply...") END;
			res := Peek(rx, ReceiverInitTimeout, ch);
			IF (res = Ok) THEN
				IF DebugR THEN KernelLog.String("got "); KernelLog.Hex(ORD(ch), -2); KernelLog.Char("X"); KernelLog.Ln END;
				CASE ch OF
				| SOH: IF DebugR THEN KernelLog.String("  new state = RData"); KernelLog.Ln END; state := RData
				| EOT: IF DebugR THEN KernelLog.String("  new state = Abort"); KernelLog.Ln END;
					COPY("ReceiveInitCRC: got EOT", msg); state := Abort
				ELSE
					INC(retries); (* state stays the same (RInitCRC) *)
					COPY("ReceiveInitCRC: wrong reply", msg);
					IF DebugR THEN KernelLog.String("  retries = "); KernelLog.Int(retries, 0); KernelLog.Ln END
				END
			ELSE (* timeout *)
				INC(crcThreshold);
				IF DebugR THEN KernelLog.String("  timeout, CRC-threshold = "); KernelLog.Int(crcThreshold, 0); KernelLog.Ln END;
				IF (crcThreshold = MaxCRCThreshold) THEN
					IF DebugR THEN KernelLog.String("  switching to checksum-mode"); KernelLog.Ln END;
					crc := FALSE; retries := 0; state := RInitChksum
				END (* ELSE state stays the same (RInitCRC) *)
			END
		END ReceiveInitCRC;

		PROCEDURE ReceiveInitChecksum;
		VAR res: WORD; ch: CHAR;
		BEGIN
			packetSize := PacketSizeChksum;
			(* send NAK *)
			tx.Char(NAK); tx.Update;

			(* wait for transmission to begin *)
			res := Peek(rx, ReceiverInitTimeout, ch);
			IF (res = Ok) THEN
				state := RData
			ELSE (* timeout *)
				COPY("ReceiveInitChecksum: timeout", msg);
				INC(retries)	(* state stays the same (RInitChksum) *)
			END
		END ReceiveInitChecksum;

		PROCEDURE ReceiveData;
		VAR buffer: POINTER TO ARRAY OF CHAR; ch: CHAR; res, i, idx, c, cc: LONGINT; ok: BOOLEAN;
		BEGIN
			NEW(buffer,packetSize);
			IF DebugR THEN
				KernelLog.String("ReceiveData:"); KernelLog.Ln; KernelLog.String("  waiting for first byte...")
			END;
			(* get first byte (SOH/EOT) *)
			res := Peek(rx, ReceiverDataTimeout, ch);

			IF (res = 0) & ((ch = SOH) OR (ch = EOT)) THEN
				IF DebugR THEN KernelLog.String("got "); KernelLog.Hex(ORD(ch), -2); KernelLog.Char("X"); KernelLog.Ln END;
				IF (ch = SOH) THEN
					IF DebugR THEN KernelLog.String("  receiving "); KernelLog.Int(packetSize, 0); KernelLog.String(" bytes...") END;
					(* receive packetSize bytes *)
					i := 0; res := 0;
					WHILE (i < packetSize) & (res = 0) DO
						res := Get(rx, ReceiverDataTimeout, buffer[i]);
						INC(i)
					END;
					IF DebugR THEN KernelLog.String("done (got "); KernelLog.Int(i, 0); KernelLog.String(" bytes)"); KernelLog.Ln END;

					IF (res = 0) THEN
						idx := GetHeader(buffer^);
						IF (idx = blockIndex MOD 100H) THEN	(* correct block number *)
							(* check checksum/CRC *)
							IF crc THEN
								c := LONG(ORD(buffer[HeaderSize+BlockSize]))*100H+ORD(buffer[HeaderSize+BlockSize+1]);
								cc := CalcCRC(buffer^, HeaderSize, BlockSize);
								IF DebugR & (c # cc) THEN
									KernelLog.String("  wrong checksum: "); KernelLog.Hex(cc, 8); KernelLog.String(", expected "); KernelLog.Hex(c, 8); KernelLog.Ln
								END;
								ok := c = c
							ELSE
								ok := CalcCheckSum(buffer^, HeaderSize, BlockSize) = buffer[HeaderSize+BlockSize]
							END;

							IF ok THEN
								IF DebugR THEN
									KernelLog.String("  received block "); KernelLog.Int(blockIndex, 0); KernelLog.Ln
								END;
								PutData(buffer^, HeaderSize, BlockSize);
								INC(blockIndex);
								tx.Char(ACK); tx.Update
							ELSE
								COPY("ReceiveData: checksum error", msg);
								IF DebugR THEN KernelLog.String("  checksum error"); KernelLog.Ln END;
								INC(retries);
								tx.Char(NAK); tx.Update
							END
						ELSIF (idx = (blockIndex-1) MOD 100H) THEN	(* maybe the sender lost our ACK *)
							COPY("ReceiveData: got block n-1", msg);
							IF DebugR THEN KernelLog.String("  got block n-1"); KernelLog.Ln END;
							INC(retries); tx.Char(ACK); tx.Update
						ELSE
							COPY("ReceiveData: wrong block number", msg);
							state := Abort;
							IF DebugR THEN
								KernelLog.String("  wrong block number"); KernelLog.Int(idx, 5); KernelLog.String(", expected ");
								KernelLog.Int(blockIndex, 0); KernelLog.Ln
							END
						END
					ELSE
						COPY("ReceiveData: timeout while receiving block", msg);
						state := Abort
					END
				ELSE (* ch = EOT *)
					IF (blockIndex = 1) THEN
						COPY("ReceiveData: got EOT instead of first block", msg);
						state := Abort
					ELSE
						tx.Char(ACK); tx.Update; state := Exit
					END
				END
			ELSE (* timeout/wrong character *)
				COPY("ReceiveData: timeout/wrong packet", msg);
				IF DebugR THEN
					KernelLog.String("timeout/wrong packet; res = "); KernelLog.Int(res, 0); KernelLog.String("; ch = ");
						KernelLog.Hex(ORD(ch), -2); KernelLog.Ln
				END;
				INC(retries);
				Purge(rx);
				tx.Char(NAK); tx.Update
			END
		END ReceiveData;

		PROCEDURE Receive*(): LONGINT;
		BEGIN
			Purge(rx);
			WHILE (state # Abort) & (state # Exit) & (retries < MaxRetries) DO
				CASE state OF
				| RInitCRC: ReceiveInitCRC
				| RInitChksum: ReceiveInitChecksum
				| RData: ReceiveData
				END
			END;
			data.Update;
			IF (state = Exit) THEN RETURN Ok
			ELSE RETURN Error
			END
		END Receive;
	END XMReceiver;

END XModem.

ystem.Free TestXModem XModem.Mod ~
