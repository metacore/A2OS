MODULE TFTPServer; (** AUTHOR "be"; PURPOSE "TFTP server"; *)

IMPORT IP, UDP, Files, Kernel, KernelLog, Random;

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

	RRQId = "TFTP RRQ: ";
	WRQId = "TFTP WRQ: ";
	TFTPId = "TFTP Server: ";

TYPE
	ErrorMsg = ARRAY 32 OF CHAR;

	TFTP = OBJECT
		VAR socket: UDP.Socket;
			fip: IP.Adr;
			lport, fport: SIGNED32;
			res: INTEGER;
			dead: BOOLEAN;
			buf: ARRAY BlockSize + 4 OF CHAR;
			timer: Kernel.Timer;

		(* Log functions *)
		PROCEDURE LogEnter(level: INTEGER);
		BEGIN IF (TraceLevel >= level) THEN KernelLog.Enter END
		END LogEnter;

		PROCEDURE LogExit(level: INTEGER);
		BEGIN IF (TraceLevel >= level) THEN KernelLog.Exit END
		END LogExit;

		PROCEDURE Log(level: INTEGER; CONST s: ARRAY OF CHAR);
		BEGIN IF (TraceLevel >= level) THEN KernelLog.String(s) END
		END Log;

		PROCEDURE LogInt(level: INTEGER; i: SIZE);
		BEGIN IF (TraceLevel >= level) THEN KernelLog.Int(i, 0) END
		END LogInt;

		(* Get2 - reads a (big endian) 16bit value from 'buf' at position 'ofs'..'ofs'+1 *)
		PROCEDURE Get2(CONST buf: ARRAY OF CHAR; ofs: SIZE): SIGNED32;
		BEGIN RETURN ORD(buf[ofs])*100H + ORD(buf[ofs+1])
		END Get2;

		(* Put2 - writes a (big endian) 16bit value to 'buf' at position 'ofs'..'ofs'+1 *)
		PROCEDURE Put2(VAR buf: ARRAY OF CHAR; ofs: SIZE; value: SIGNED32);
		BEGIN buf[ofs] := CHR(value DIV 100H MOD 100H); buf[ofs+1] := CHR(value MOD 100H)
		END Put2;

		(* PacketType - returns the type of a packet *)
		PROCEDURE PacketType(CONST buf: ARRAY OF CHAR): SIGNED32;
		BEGIN RETURN Get2(buf, 0)
		END PacketType;

		(* ExtractString - extracts a 0X terminated 8bit string from a buffer *)
		PROCEDURE ExtractString(CONST buf: ARRAY OF CHAR; VAR ofs: SIZE; VAR s: ARRAY OF CHAR);
		VAR pos: SIGNED32;
		BEGIN
			WHILE (ofs < LEN(buf)) & (buf[ofs] # 0X) DO
				IF (pos < LEN(s)-1) THEN s[pos] := buf[ofs]; INC(pos) END;
				INC(ofs)
			END;
			s[pos] := 0X; INC(ofs)
		END ExtractString;

		(* SendAck - sends an ack packet *)
		PROCEDURE SendAck(blockNr: SIGNED32; VAR res: INTEGER);
		VAR ackHdr: ARRAY 4 OF CHAR; retries: SIGNED32;
		BEGIN
			Put2(ackHdr, 0, ACK); Put2(ackHdr, 2, blockNr);
			REPEAT
				INC(retries);
				socket.Send(fip, fport, ackHdr, 0, LEN(ackHdr), res);
			UNTIL (res = Ok) OR (retries > MaxRetries)
		END SendAck;

		(* SendError - sends an error packet *)
		PROCEDURE SendError(errNo: SIGNED16; s: ErrorMsg; VAR res: INTEGER);
		VAR errHdr: ARRAY BlockSize+4 OF CHAR; p, retries: SIGNED32;
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

		PROCEDURE Die;
		BEGIN { EXCLUSIVE }
			dead := TRUE
		END Die;

		PROCEDURE AwaitDeath;
		BEGIN { EXCLUSIVE }
			AWAIT(dead)
		END AwaitDeath;
	END TFTP;

	TFTPRRQ = OBJECT(TFTP)
		VAR
			ip: IP.Adr;
			ack: ARRAY 4 OF CHAR;
			port, wait, retries, blockNr: SIGNED32;
			len: SIZE;
			acked: BOOLEAN;
			file: Files.File;
			r: Files.Rider;

		(* Init - constructor *)
		PROCEDURE &Init*(fip: IP.Adr; fport: SIGNED32; CONST filename: Files.FileName; VAR res: INTEGER);
		VAR retries: SIGNED32;
		BEGIN SELF.fip := fip; SELF.fport := fport;
			file := Files.Old(filename);
			IF (file # NIL) THEN
				REPEAT
					INC(retries); lport := 1024 + generator.Integer() MOD 64512;
					NEW(socket, lport, res);
				UNTIL (res # UDP.PortInUse) OR (retries > MaxSocketRetries)
			ELSE
				res := -1
			END
		END Init;

	BEGIN {ACTIVE}
		IF (socket = NIL) THEN RETURN END;
		LogEnter(2); Log(2, RRQId); Log(2, "sending file on port "); LogInt(2, lport); Log(2, "..."); LogExit(2);
		file.Set(r, 0);
		Put2(buf, 0, 3); (* DATA packet *)
		blockNr := 0; acked := TRUE;
		WHILE ~r.eof & acked DO
			INC(blockNr);
			buf[2] := CHR(blockNr DIV 100H); buf[3] := CHR(blockNr MOD 100H);
			file.ReadBytes(r, buf, 4, BlockSize);
			retries := 0;
			REPEAT
				INC(retries);
				LogEnter(3); Log(3, RRQId); Log(3, "sending block "); LogInt(3, blockNr);
				Log(3, " ("); LogInt(3, BlockSize-r.res); Log(3, " bytes) ");
				IF (retries > 1) THEN Log(3, "(retry "); LogInt(3, retries); Log(3, ")") END;
				LogExit(3);

				socket.Send(fip, fport, buf, 0, 4 + BlockSize - r.res, res);
				wait := 0;
				REPEAT
					INC(wait);
					LogEnter(3); Log(3, RRQId); Log(3, "waiting for ack... ");
					IF (wait > 1) THEN Log(3, "(retry "); LogInt(3, wait); Log(3, ")") END;
					LogExit(3);
					acked := FALSE;
					socket.Receive(ack, 0, 4, AckTimeout, ip, port, len, res);

					LogEnter(3); Log(3, RRQId);
					IF (res = UDP.Timeout) THEN Log(3, "timeout")
					ELSIF (res = Ok) THEN
						acked := (res = Ok) & (PacketType(ack) = ACK) & (Get2(ack, 2) = blockNr) & (IP.AdrsEqual(ip, fip)) & (fport = port);
						IF acked THEN Log(3, "got ack") ELSE Log(3, "ack failed") END
					ELSE
						Log(3, "unknown error "); LogInt(3, SIGNED32(res))
					END;
					LogExit(3)
				UNTIL acked OR (res # Ok) OR (wait > MaxWait)
			UNTIL acked OR (retries > MaxRetries)
		END;
		LogEnter(2); Log(2, RRQId);
		IF ~acked THEN Log(2, "file not completely sent")
		ELSE Log(2, "file successfully sent")
		END;
		LogExit(2);
		NEW(timer);
		timer.Sleep(AckTimeout+500);
		Die
	END TFTPRRQ;

	TFTPWRQ = OBJECT(TFTP)
		VAR
			ip: IP.Adr;
			port, waitPacket, retries, blockNr: SIGNED32;
			len: SIZE;
			Abort: BOOLEAN;
			file: Files.File;
			r: Files.Rider;

		(* Init - constructor *)
		PROCEDURE &Init*(fip: IP.Adr; fport: SIGNED32; CONST filename: Files.FileName; VAR res: INTEGER);
		VAR retries: SIGNED32;
		BEGIN
			SELF.fip := fip; SELF.fport := fport; res := 0;
			file := Files.Old(filename);
			IF (file = NIL) THEN
				file := Files.New(filename);
				IF (file = NIL) THEN
					LogEnter(1); Log(1, TFTPId); Log(1, "unexpected error: can't create '"); Log(1, filename); Log(1, "'"); LogExit(1);
					res := -1;
				ELSE
					REPEAT
						INC(retries); lport := 1024 + generator.Integer() MOD 64512;
						NEW(socket, lport, res)
					UNTIL (res # UDP.PortInUse) OR (retries > MaxSocketRetries)
				END
			ELSE
				res := -1
			END
		END Init;

	BEGIN {ACTIVE}
		IF (socket = NIL) THEN RETURN END;
		LogEnter(2); Log(2, WRQId); Log(2, "receiving file on port "); LogInt(2, lport); Log(2, "..."); LogExit(2);
		file.Set(r, 0);
		Files.Register(file);
		blockNr := 0;
		SendAck(blockNr, res);
		IF (res = Ok) THEN
			REPEAT
				INC(blockNr);
				LogEnter(3); Log(3, WRQId); Log(3, " receiving block "); LogInt(3, blockNr);
				IF (retries > 1) THEN Log(3, " (retry "); LogInt(3, retries); Log(3, ")") END;
				LogExit(3);
					socket.Receive(buf, 0, LEN(buf), DataTimeout, ip, port, len, res);
					IF (res = Ok) THEN
						IF IP.AdrsEqual(ip, fip) & (fport = port) THEN
							IF (PacketType(buf) = DATA) THEN
								IF (Get2(buf, 2) = blockNr) THEN
									file.WriteBytes(r, buf, 4, len-4);
									file.Update();
									IF (r.res = 0) THEN
										SendAck(blockNr, res);
										Abort := res # Ok
									ELSE
										LogEnter(3); Log(3, WRQId); Log(3, errorMsg[3]); LogExit(3);
										SendError(3, "", res);
										Abort := TRUE
									END
								ELSE (* bad block number, client must send packet again *)
									INC(waitPacket); len := BlockSize;
									LogEnter(3); Log(3, WRQId); Log(3, "Bad block number ("); LogInt(3, waitPacket); Log(3, ")"); LogExit(3)
								END
							ELSE (* wrong packet type *)
								LogEnter(3); Log(3, WRQId); Log(3, errorMsg[4]); LogExit(3);
								SendError(4, "", res);
								Abort := TRUE
							END
						ELSE (* wrong client ip/port *)
							LogEnter(3); Log(3, WRQId); Log(3, errorMsg[5]); LogExit(3);
							SendError(5,"", res)
						END
					ELSIF (res = UDP.Timeout) THEN
						INC(waitPacket); len := BlockSize;
						LogEnter(3); Log(3, WRQId); Log(3, "Timeout ("); LogInt(3, waitPacket); Log(3, ")"); LogExit(3)
					ELSE (* unknown error (UDP/IP error) *)
						LogEnter(3); Log(3, WRQId); Log(3, errorMsg[0]); LogExit(3);
						SendError(0, "", res);
						Abort := TRUE
					END;
			UNTIL Abort OR (waitPacket > MaxWait) OR (len < BlockSize);

			LogEnter(2); Log(2, WRQId);
			IF (len < BlockSize) THEN
				file.Update();
				Log(2, "file successfully received")
			ELSE
				Log(2, "file transfer aborted");
				IF (waitPacket > MaxWait) THEN Log(2, " (timeout)") END
			END;
			LogExit(2)
		ELSE
			LogEnter(2); Log(2, WRQId); Log(2, "can't send initial ack"); LogExit(2);
		END;
		NEW(timer);
		timer.Sleep(AckTimeout+500);
		socket.Close;
		Die
	END TFTPWRQ;

	TFTPServer = OBJECT(TFTP)
		VAR
			ofs,len: SIZE;
			ipstr, mode: ARRAY 16 OF CHAR;
			filename: Files.FileName;
			Stop, allowWrite: BOOLEAN;
			tftprrq: TFTPRRQ;
			tftpwrq: TFTPWRQ;

		PROCEDURE &Init*(port: SIGNED32; VAR res: INTEGER);
		BEGIN NEW(socket, port, res); lport := port
		END Init;

		PROCEDURE WriteMode(allow: BOOLEAN);
		BEGIN allowWrite := allow
		END WriteMode;

		PROCEDURE Close;
		BEGIN { EXCLUSIVE }
			socket.Close; Stop := TRUE
		END Close;

	BEGIN { ACTIVE }
		IF (res = Ok) THEN
			LogEnter(1); Log(1, TFTPId); Log(1, "listening on port "); LogInt(1, lport); LogExit(1);
			REPEAT
				socket.Receive(buf, 0, LEN(buf), 1000, fip, fport, len, res);
				IF (res = Ok) THEN
					IP.AdrToStr(fip, ipstr);
					LogEnter(2);
					Log(2, TFTPId); Log(2, "connected to "); Log(2, ipstr); Log(2, " on port "); LogInt(2, fport);
					LogExit(2);
					CASE PacketType(buf) OF
					| RRQ:
							ofs := 2;
							ExtractString(buf, ofs, filename); ExtractString(buf, ofs, mode);
							LogEnter(2);
							Log(2, TFTPId); Log(2, "read request for '"); Log(2, filename); Log(2, "', mode '");  Log(2, mode); Log(2, "' ");
							LogExit(2);
							NEW(tftprrq, fip, fport, filename, res); tftprrq := NIL;
							IF (res = -1) THEN
								LogEnter(2); Log(2, TFTPId); Log(2, "read request: "); Log(2, errorMsg[1]); LogExit(2);
								SendError(1, "", res)
							ELSIF (res # Ok) THEN
								LogEnter(2); Log(2, TFTPId); Log(2, "read request: "); Log(2, ": error "); LogInt(2, SIGNED32(res)); LogExit(2);
								SendError(0, "", res)
							ELSE
								LogEnter(2); Log(2, TFTPId); Log(2, "read request: "); Log(2, ": transfer started"); LogExit(2)
							END
					| WRQ:
							ofs := 2;
							ExtractString(buf, ofs, filename); ExtractString(buf, ofs, mode);
							LogEnter(2);
							Log(2, TFTPId); Log(2, "write request for '"); Log(2, filename); Log(2, "', mode '"); Log(2, mode); Log(2, "' ");
							LogExit(2);
							IF allowWrite THEN
								NEW(tftpwrq, fip, fport, filename, res); tftpwrq := NIL;
								IF (res = -1) THEN
									LogEnter(2); Log(2, TFTPId); Log(2, "write request: "); Log(2, errorMsg[6]); LogExit(2);
									SendError(6, "", res)
								ELSIF (res # Ok) THEN
									LogEnter(2); Log(2, TFTPId); Log(2, "write request: "); Log(2, ": error "); LogInt(2, SIGNED32(res)); LogExit(2);
									SendError(0, "", res)
								ELSE
									LogEnter(2); Log(2, TFTPId); Log(2, "write request: "); Log(2, ": transfer started"); LogExit(2)
								END
							ELSE
								LogEnter(2); Log(2, TFTPId); Log(2, "write request: "); Log(2, errorMsg[2]); LogExit(2);
								SendError(2, "", res)
							END
					ELSE LogEnter(2); Log(2, TFTPId); Log(2, "Invalid request"); LogExit(2)
					END
				ELSIF (res = UDP.Timeout) THEN (* nothing *)
				ELSE
					Stop := TRUE;
					LogEnter(2); Log(2, TFTPId); Log(2, "socket error "); LogInt(2, SIGNED32(res)); LogExit(2);
				END
			UNTIL Stop;
		END;
		Die
	END TFTPServer;

VAR
	tftpserver: TFTPServer;
	TraceLevel: INTEGER;
	errorMsg: ARRAY 8 OF ErrorMsg;
	generator: Random.Generator;

PROCEDURE Start*;
VAR res: INTEGER;
BEGIN
	IF (tftpserver = NIL) THEN
		KernelLog.Enter; KernelLog.String("Starting TFTP Server..."); KernelLog.Exit;
		NEW(tftpserver, TFTPPort, res);
		IF (res # UDP.Ok) THEN
			tftpserver := NIL;
			KernelLog.Enter; KernelLog.String("TFTP Server: UDP port not available"); KernelLog.Exit
		END
	ELSE
		KernelLog.Enter; KernelLog.String("TFTP Server: already running"); KernelLog.Exit
	END
END Start;

PROCEDURE Stop*;
BEGIN
	IF (tftpserver # NIL) THEN
		tftpserver.Close; tftpserver.AwaitDeath; tftpserver := NIL;
		KernelLog.Enter; KernelLog.String("TFTP Server stopped"); KernelLog.Exit
	ELSE
		KernelLog.Enter; KernelLog.String("TFTP Server not running"); KernelLog.Exit
	END
END Stop;

PROCEDURE AllowWrite*;
BEGIN
	IF (tftpserver # NIL) THEN
		tftpserver.WriteMode(TRUE);
		KernelLog.Enter; KernelLog.String("TFTP Server: writing allowed"); KernelLog.Exit
	ELSE
		KernelLog.Enter; KernelLog.String("TFTP Server: not running. use TFTPServer.Start"); KernelLog.Exit
	END
END AllowWrite;

PROCEDURE DenyWrite*;
BEGIN
	IF (tftpserver # NIL) THEN
		tftpserver.WriteMode(FALSE);
		KernelLog.Enter; KernelLog.String("TFTP Server: writing denied"); KernelLog.Exit;
	ELSE
		KernelLog.Enter; KernelLog.String("TFTP Server: not running. use TFTPServer.Start"); KernelLog.Exit
	END
END DenyWrite;

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
	TraceLevel := 2;
	NEW(generator)
END TFTPServer.


System.Free TFTPServer ~

TFTPServer.Start
TFTPServer.Stop

TFTPServer.AllowWrite
TFTPServer.DenyWrite

TFTPServer.TraceLevel0
TFTPServer.TraceLevel1
TFTPServer.TraceLevel2
TFTPServer.TraceLevel3
