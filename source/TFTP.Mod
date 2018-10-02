MODULE TFTP; (** AUTHOR "be"; PURPOSE "TFTP client"; *)

IMPORT IP, UDP, Files, Random, KernelLog;

CONST
	Ok = UDP.Ok;

	(* General Settings *)
	TFTPPort = 69;
	MaxSocketRetries = 64;
	MaxRetries = 5;
	MaxWait = 3;
	BlockSize = 512;
	DataTimeout = 3000; (* ms *)
	AckTimeout = 3000; (* ms *)

	(* Packet Types *)
	RRQ = 1;
	WRQ = 2;
	DATA = 3;
	ACK = 4;
	ERROR = 5;

	TFTPId = "TFTP Client: ";

TYPE
	ErrorMsg = ARRAY 32 OF CHAR;

	TFTPClient* = OBJECT
		(* Log functions *)
		PROCEDURE LogEnter(level: LONGINT);
		BEGIN IF (TraceLevel >= level) THEN KernelLog.Enter END
		END LogEnter;

		PROCEDURE LogExit(level: LONGINT);
		BEGIN IF (TraceLevel >= level) THEN KernelLog.Exit END
		END LogExit;

		PROCEDURE Log(level: LONGINT; s: ARRAY OF CHAR);
		BEGIN IF (TraceLevel >= level) THEN KernelLog.String(s) END
		END Log;

		PROCEDURE LogInt(level, i: LONGINT);
		BEGIN IF (TraceLevel >= level) THEN KernelLog.Int(i, 0) END
		END LogInt;

		(* Get2 - reads a (big endian) 16bit value from 'buf' at position 'ofs'..'ofs'+1 *)
		PROCEDURE Get2(VAR buf: ARRAY OF CHAR; ofs: LONGINT): LONGINT;
		BEGIN RETURN ORD(buf[ofs])*100H + ORD(buf[ofs+1])
		END Get2;

		(* Put2 - writes a (big endian) 16bit value to 'buf' at position 'ofs'..'ofs'+1 *)
		PROCEDURE Put2(VAR buf: ARRAY OF CHAR; ofs, value: LONGINT);
		BEGIN buf[ofs] := CHR(value DIV 100H MOD 100H); buf[ofs+1] := CHR(value MOD 100H)
		END Put2;

		(* PacketType - returns the type of a packet *)
		PROCEDURE PacketType(VAR buf: ARRAY OF CHAR): LONGINT;
		BEGIN RETURN Get2(buf, 0)
		END PacketType;

		(* ExtractString - extracts a 0X terminated 8bit string from a buffer *)
		PROCEDURE ExtractString(VAR buf: ARRAY OF CHAR; VAR ofs: LONGINT; VAR s: ARRAY OF CHAR);
		VAR pos: LONGINT;
		BEGIN
			WHILE (ofs < LEN(buf)) & (buf[ofs] # 0X) DO
				IF (pos < LEN(s)-1) THEN s[pos] := buf[ofs]; INC(pos) END;
				INC(ofs)
			END;
			s[pos] := 0X; INC(ofs)
		END ExtractString;

		(* PutString - puts a 0X terminated 8bit string to a buffer *)
		PROCEDURE PutString(VAR buf: ARRAY OF CHAR; VAR ofs: LONGINT; s: ARRAY OF CHAR);
		VAR pos: LONGINT;
		BEGIN
			WHILE (pos < LEN(s)) & (s[pos] # 0X) DO
				IF (ofs < LEN(buf)-1) THEN buf[ofs] := s[pos]; INC(ofs) END;
				INC(pos)
			END;
			buf[ofs] := 0X; INC(ofs)
		END PutString;

		(* ReceiveAck - receives a server answer *)
		PROCEDURE ReceiveAck(socket: UDP.Socket; VAR fip: IP.Adr; VAR fport: LONGINT; blockNr: LONGINT; VAR ack: ARRAY OF CHAR): BOOLEAN;
		VAR ip: IP.Adr; port, len, ofs, wait: LONGINT; res: WORD; acked: BOOLEAN; msg: ARRAY 256 OF CHAR;
		BEGIN
			wait := 0;
			REPEAT
				INC(wait);
				LogEnter(3); Log(3, TFTPId); Log(3, "waiting for ack... ");
				IF (wait > 1) THEN Log(3, "(retry "); LogInt(3, wait); Log(3, ")") END;
				LogExit(3);
				acked := FALSE;
				socket.Receive(ack, 0, LEN(ack), AckTimeout, ip, port, len, res);

				LogEnter(3); Log(3, TFTPId);
				IF (res = UDP.Timeout) THEN Log(3, "timeout")
				ELSIF (res = UDP.BufferOverflow) THEN Log(3, "buffer overflow ("); LogInt(3, -len); Log(3, " bytes)")
				ELSIF (res = Ok) THEN
					acked := (PacketType(ack) = ACK) & (Get2(ack, 2) = blockNr)  & (IP.AdrsEqual(ip, fip)) & ((fport = port) OR (fport = -1));
					IF acked THEN Log(3, "got ack") ELSE Log(3, "ack failed") END;
					IF (PacketType(ack) = ERROR) THEN
						wait := MaxWait + 1;
						ofs := 4; ExtractString(ack, ofs, msg);
						Log(3, "; error "); LogInt(3, Get2(ack, 2)); Log(3, ": "); Log(3, msg)
					END
				ELSE
					Log(3, "unknown error "); LogInt(3, res)
				END;
				LogExit(3)
			UNTIL acked OR (res # Ok) OR (wait > MaxWait);
			IF acked & (fport = -1) THEN fport := port END;
			RETURN acked
		END ReceiveAck;

		(* SendAck - sends an ack packet *)
		PROCEDURE SendAck(socket: UDP.Socket; fip: IP.Adr; fport: LONGINT; blockNr: LONGINT; VAR res: WORD);
		VAR ackHdr: ARRAY 4 OF CHAR; retries: LONGINT;
		BEGIN
			Put2(ackHdr, 0, ACK); Put2(ackHdr, 2, blockNr);
			REPEAT
				INC(retries);
				socket.Send(fip, fport, ackHdr, 0, LEN(ackHdr), res);
			UNTIL (res = Ok) OR (retries > MaxRetries)
		END SendAck;

		(* SendError - sends an error packet *)
		PROCEDURE SendError(socket: UDP.Socket; fip: IP.Adr; fport: LONGINT; errNo: INTEGER; s: ErrorMsg; VAR res: WORD);
		VAR errHdr: ARRAY BlockSize+4 OF CHAR; p, retries: LONGINT;
		BEGIN
			Put2(errHdr, 0, ERROR); Put2(errHdr, 2, errNo);
			IF ((errNo = 0) & (s = "")) OR ((errNo > 0) & (errNo < 8)) THEN s := errorMsg[errNo] END;
			WHILE (p < BlockSize-1) & (s[p] # 0X) DO errHdr[4+p] := s[p]; INC(p) END;
			errHdr[4+p] := 0X;
			REPEAT
				INC(retries);
				socket.Send(fip, fport, errHdr, 0, p+4, res)
			UNTIL (res = Ok) OR (retries > MaxRetries)
		END SendError;

		(* GetSocket - finds & initializes a free UDP socket *)
		PROCEDURE GetSocket*(VAR socket: UDP.Socket): BOOLEAN;
		VAR retries, lport: LONGINT; res: WORD;
		BEGIN
			REPEAT
				INC(retries); lport := 1024 + generator.Integer() MOD 64512;
				NEW(socket, lport, res)
			UNTIL (res # UDP.PortInUse) OR (retries > MaxSocketRetries);
			IF (res = UDP.PortInUse) THEN socket := NIL END;
			RETURN (socket # NIL)
		END GetSocket;

		(* Send - send a file to TFTP server at fip:fport *)
		PROCEDURE Send*(localFN, remoteFN: ARRAY OF CHAR; fip: IP.Adr; fport: LONGINT): BOOLEAN;
		VAR buf, ack: ARRAY 4+BlockSize OF CHAR; socket: UDP.Socket; msg: ARRAY 256 OF CHAR;
			file: Files.File; r: Files.Rider; ofs, retries, blockNr, errNo: LONGINT; res: WORD; acked: BOOLEAN;
		BEGIN
			acked := FALSE;
			file := Files.Old(localFN);
			IF (file # NIL) THEN
				IF GetSocket(socket) THEN
					LogEnter(1); Log(1, TFTPId); Log(1, "sending '"); Log(1, localFN); Log(1, "'"); LogExit(1);
					file.Set(r, 0);
					(* issue a WRQ *)
					Put2(buf, 0, WRQ);
					ofs := 2;
					PutString(buf, ofs, remoteFN);
					PutString(buf, ofs, "netascii");
					socket.Send(fip, fport, buf, 0, ofs, res);

					(* wait for ACK/ERROR *)
					fport := -1; (* allow change of fport *)
					IF ReceiveAck(socket, fip, fport, 0, ack) THEN
						(* send file *)
						blockNr := 0; acked := TRUE;
						WHILE ~r.eof & acked DO
							INC(blockNr);
							Put2(buf, 0, DATA);
							Put2(buf, 2, blockNr);
							file.ReadBytes(r, buf, 4, BlockSize);

							REPEAT
								INC(retries);
								LogEnter(3); Log(3, TFTPId); Log(3, "sending block "); LogInt(3, blockNr);
								Log(3, " ("); LogInt(3, BlockSize-r.res); Log(3, " bytes) ");
								IF (retries > 1) THEN Log(3, "(retry "); LogInt(3, retries); Log(3, ")") END;
								LogExit(3);
								socket.Send(fip, fport, buf, 0, 4 + BlockSize - r.res, res);
								acked := ReceiveAck(socket, fip, fport, blockNr, ack)
							UNTIL acked OR (retries > MaxRetries);
						END;
						LogEnter(1); Log(1, TFTPId);
						IF r.eof & acked THEN Log(1, "file successfully sent")
						ELSE
							Log(1, "sending failed");
							IF (PacketType(ack) = ERROR) THEN
								Log(1, ":");
								errNo := Get2(ack, 2);
								IF (errNo > 0) & (errNo < 8) THEN Log(1, errorMsg[errNo])
								ELSIF (errNo = 0) THEN
										ofs := 4;
									ExtractString(ack, ofs, msg);
									Log(1, msg)
								END
							END
						END;
						LogExit(1)
					ELSE	(* no ACK or block number # 0 *)
						LogEnter(1); Log(1, TFTPId); Log(1, TFTPId); Log(1, "sending failed");
						IF (PacketType(ack) = ERROR) THEN
							Log(1, ": ");
							errNo := Get2(ack, 2);
							IF (errNo > 0) & (errNo < 8) THEN Log(1, errorMsg[errNo])
							ELSIF (errNo = 0) THEN
								ofs := 4;
								ExtractString(ack, ofs, msg);
								Log(1, msg)
							END
						END;
						LogExit(1)
					END;
					socket.Close
				ELSE
					LogEnter(1); Log(1, TFTPId); Log(1, "can't get a free socket"); LogExit(1)
				END
			ELSE
				LogEnter(1); Log(1, TFTPId); Log(1, "file not found"); LogExit(1)
			END;
			RETURN acked
		END Send;

		(* Receive - receive a file from TFTP server at source:port *)
		PROCEDURE Receive*(remoteFN, localFN: ARRAY OF CHAR; fip: IP.Adr; fport: LONGINT): BOOLEAN;
		VAR socket: UDP.Socket; ofs, blockNr, port, len, retries, waitPacket: LONGINT; res: WORD; ok, Abort: BOOLEAN; ip: IP.Adr;
			buf: ARRAY 4+BlockSize OF CHAR; file: Files.File; r: Files.Rider;
		BEGIN
			ok := FALSE;
			IF GetSocket(socket) THEN
				LogEnter(1); Log(1, TFTPId); Log(1, "receiving '"); Log(1, remoteFN); Log(1, "'"); LogExit(1);
				(* issue a RRQ *)
				Put2(buf, 0, RRQ);
				ofs := 2;
				PutString(buf, ofs, remoteFN);
				PutString(buf, ofs, "netascii");
				socket.Send(fip, fport, buf, 0, ofs, res);

				fport := -1; (* allow change of fport *)
				file := Files.New(localFN);
				ASSERT(file # NIL);
				file.Set(r, 0);
				Files.Register(file);
				blockNr := 0;

				REPEAT
					INC(blockNr);
					LogEnter(3); Log(3, TFTPId); Log(3, "receiving block "); LogInt(3, blockNr);
					IF (retries > 1) THEN Log(3, " (retry "); LogInt(3, retries); Log(3, ")") END;
					LogExit(3);

					REPEAT
						socket.Receive(buf, 0, LEN(buf), DataTimeout, ip, port, len, res);
						DEC(len, 4);

						IF (res = Ok) THEN
							res := -1;
							IF (IP.AdrsEqual(ip, fip)) & ((fport = port) OR (fport = -1)) THEN
								IF (fport = -1) THEN fport := port END;
								IF (PacketType(buf) = DATA) THEN
									IF (Get2(buf, 2) = blockNr) THEN
										file.WriteBytes(r, buf, 4, len);
										file.Update();
										IF (r.res = 0) THEN
											LogEnter(3); Log(3, TFTPId); LogInt(3, len); Log(3, " bytes written"); LogExit(3);
											SendAck(socket, fip, fport, blockNr, res);
											Abort := res # Ok
										ELSE
											LogEnter(3); Log(3, TFTPId); Log(3, errorMsg[3]); LogExit(3);
											SendError(socket, fip, fport, 3, "", res);
											Abort := TRUE
										END
									ELSE (* bad block number *)
										INC(waitPacket); len := BlockSize;
										LogEnter(3); Log(3, TFTPId); Log(3, "Bad block number (expected "); LogInt(3, blockNr);
										Log(3, ", got "); LogInt(3, Get2(buf, 2)); Log(3, ")"); LogExit(3)
									END
								ELSE (* wrong packet type *)
									LogEnter(3); Log(3, TFTPId); Log(3, errorMsg[4]); LogExit(3);
									SendError(socket, fip, fport, 4, "", res);
									Abort := TRUE
								END
							ELSE (* ip/port changed *)
								LogEnter(3); Log(3, TFTPId); Log(3, errorMsg[5]); LogExit(3);
								SendError(socket, fip, fport, 5,"", res)
							END
						ELSIF (res = UDP.Timeout) THEN
							INC(waitPacket); len := BlockSize;
							LogEnter(3); Log(3, TFTPId); Log(3, "Timeout ("); LogInt(3, waitPacket); Log(3, ")"); LogExit(3)
						ELSE (* unknown error (UDP/IP error) *)
							LogEnter(3); Log(3, TFTPId); Log(3, errorMsg[0]); LogExit(3);
							SendError(socket, fip, fport, 0, "", res);
							Abort := TRUE
						END;
					UNTIL (res = Ok) OR Abort OR (waitPacket > MaxWait);
				UNTIL Abort OR (waitPacket > MaxWait) OR (len < BlockSize);

				LogEnter(1); Log(1, TFTPId);
				IF ~Abort & (waitPacket <= MaxWait) & (len < BlockSize) THEN
					Log(1, "file successfully received");
					file.Update();
					ok := TRUE;
				ELSE
					Log(1, "error receiveing file")
				END;
				LogExit(1);
				socket.Close
			ELSE
				LogEnter(1); Log(1, TFTPId); Log(1, "can't get a free socket"); LogExit(1)
			END;
			RETURN ok
		END Receive;
	END TFTPClient;

VAR TraceLevel: LONGINT;
	errorMsg: ARRAY 8 OF ErrorMsg;
	generator: Random.Generator;

PROCEDURE Send*(localFN, remoteFN: ARRAY OF CHAR; ip: IP.Adr): BOOLEAN;
VAR client: TFTPClient;
BEGIN
	NEW(client);
	RETURN client.Send(localFN, remoteFN, ip, TFTPPort)
END Send;

PROCEDURE Receive*(removeFN, localFN: ARRAY OF CHAR; ip: IP.Adr): BOOLEAN;
VAR client: TFTPClient;
BEGIN
	NEW(client);
	RETURN client.Receive(removeFN, localFN, ip, TFTPPort)
END Receive;

PROCEDURE TraceLevel0*;
BEGIN TraceLevel := 0
END TraceLevel0;

PROCEDURE TraceLevel1*;
BEGIN TraceLevel := 1
END TraceLevel1;

PROCEDURE TraceLevel2*;
BEGIN TraceLevel := 2
END TraceLevel2;

PROCEDURE TraceLevel3*;
BEGIN TraceLevel := 3
END TraceLevel3;

BEGIN
	errorMsg[0] := "Undefined error.";
	errorMsg[1] := "File not found.";
	errorMsg[2] := "Access violation.";
	errorMsg[3] := "Disk full.";
	errorMsg[4] := "Illegal TFTP operation.";
	errorMsg[5] := "Unknown transfer ID.";
	errorMsg[6] := "File already exists.";
	errorMsg[7] := "No such user.";
	TraceLevel := 1;
	NEW(generator)
END TFTP.

TFTP.TraceLevel3

TestTFTP.Mod
