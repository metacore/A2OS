MODULE EnetTftp;
(**
	AUTHOR Timothée Martiel, 2015
	PURPOSE Ethernet network stack, TFTP protocol.
*)
IMPORT
	SYSTEM, T := Trace,
	EnetBase, EnetInterfaces, EnetStreams, EnetTiming, EnetTrace, EnetUdp;

	CONST
		(* Error Status *)
		FileNotFound * = 1;
		AccessViolation * = 2;
		DiskFull * = 3;
		IllegalOperation * = 4;
		UnknownTransferId * = 5;
		FileAlreadyExists * = 6;
		NoSuchUser * = 7;
		TimeoutExpired * = 1000;
		TransferBusy * = 1001;		(** Transfer has not yet completed and cannot be used for another file *)
		TooMuchData * = 1002;		(** User tried to send more data as there are in the file *)

		(* TFTP transfer states *)
		Idle * = 0;						(** Transfer is idle and waiting for order *)
		WaitForData * = 1;			(** Read transfer is receiving data *)
		WaitForAck * = 2;				(** Write transfer is waiting for remote acknowledge *)
		Error * = 3;					(** Transfer was terminated with an error *)
		WaitForUser * = 4;			(** Write transfer is waiting for user to provide data *)

		(* Transfer modes *)
		ModeNetAscii * = 'netascii';	(** Text file transfer mode *)
		ModeOctet * = 'octet';		(** Binary file transfer mode *)
		ModeMail * = 'mail';			(** Mail file transfer mode *)

		(* Error handling *)
		Timeout * = 5000;				(** Acknowledge and waiting timeout, in ms *)
		MaxRetries * = 3;				(** Maximal number of retries for one transmission *)

		(* Opcodes *)
		OpRequestRead * = 1;		(** Transfer is from remote to local. Warning: used as header opcode, do not change value *)
		OpRequestWrite * = 2;		(** Transfer is from local to remote. Warnong: used as header opcode, do not change value *)
		OpData = 3;
		OpAck = 4;
		OpError = 5;

		(** Data transfer block size *)
		DataTxLen = 512;
		(** TFTP Header Length *)
		HeaderLength = 4;

		(** Server listening port *)
		TftpPort = 69;
		LocalPortMin = 60000;
		LocalPortMax = 65000;

		(** Produce Tracing *)
		Trace = FALSE;

TYPE
	(**
		File transfer abstraction.
		Represents a unique file transfer. The datastructure can be reused multiple times.
	*)
	Transfer * = POINTER TO TransferDesc;
	TransferDesc * = RECORD
		data: ARRAY DataTxLen + HeaderLength OF CHAR;	(** Internal packet buffer. Holds last sent packet *)
		timeoutTask: EnetBase.TaskHandler;		(** Task for timeout handling *)
		socket: EnetUdp.Socket;					(** Underlying UDP socket *)
		remoteAdr: EnetBase.IpAddr;				(** Remote host address *)
		dataLength,								(** Length of last sent packet *)
		localPort,									(** Local UDP port on which the socket is listening *)
		remotePort: EnetBase.Int;					(** Remote host UDP port *)
		handler: DataReceiveHandler;				(** TFTP packet receiver *)
		handlerParam *: ANY;						(** Custom parameter for the packet receiver, set by the client *)
		block,										(** Current block ID *)
		remLength,								(** Remaining write transfer length (0 for read transfers *)
		retries,										(** Number of times current transfer has been retried *)
		op -,										(** OpRequestRead for read transfer or OpRequestWrite for write transfer *)
		res -,										(** Transfer result code *)
		state -: EnetBase.Int;						(** Transfer state *)
		next: Transfer;
	END;

	(**
		TFTP Receiver.
		Is called by a receive transfer on each received data blocks.
		'transfer' is the transfer, 'buf', 'ofs' and 'len' represent the received data. 'res' is the result code and 'end' signals the last block of a transfer (error or transfer completed).
		'packet' points to the receive packet if no error occurred. If 'res' is not 0 then 'packet' is NIL.
	*)
	DataReceiveHandler * = PROCEDURE {DELEGATE} (transfer: Transfer; VAR buf: ARRAY OF CHAR; ofs, len, res: EnetBase.Int; packet: EnetBase.Packet; end: BOOLEAN);
	Listener * = PROCEDURE {DELEGATE} (transfer: Transfer; CONST file, mode: ARRAY OF CHAR; packet: EnetBase.Packet; VAR res: EnetBase.Int): BOOLEAN;

	(** Object wrapper for boolean for the simple blocking task handler *)
	Boolean = POINTER TO RECORD value: BOOLEAN END;

VAR
	(** List of all transfers. Used for finding transfers by sockets *)
	transfers: Transfer;
	blockingCompletion: EnetBase.TaskHandler;
	(** Last used local port *)
	lastPort: EnetBase.Int;
	timeout: EnetTiming.Time;

	PROCEDURE SetListener * (listener: Listener; port: EnetBase.Int);
	BEGIN
	END SetListener;

	(**
		Start sending a file to host 'destination' with name 'name', mode 'mode'.
		The file is 'length' bytes long and its content is sent using 'SendData'.
	*)
	PROCEDURE WriteFile * (VAR transfer: Transfer; CONST name, mode: ARRAY OF CHAR; length: EnetBase.Int; CONST destination: EnetBase.IpAddr; VAR res: EnetBase.Int): BOOLEAN;
	BEGIN
		(* Transfer must not be used *)
		IF transfer = NIL THEN
			NEW(transfer);
			transfer.next := transfers;
			transfers := transfer
		END;
		IF (transfer.state # Idle) & (transfer.state # Error) THEN res := TransferBusy; RETURN FALSE END;

		(* Setup UDP layer *)
		transfer.localPort := GetLocalPort();
		IF (transfer.socket = NIL) & ~EnetUdp.NewSocket(transfer.socket, transfer.localPort, res) THEN RETURN FALSE END;
		transfer.remoteAdr := destination;
		transfer.remotePort := TftpPort;
		blockingCompletion := GetBlockingCompletion();
		IF ~EnetUdp.SetRecvHandler(transfer.socket, HandlePacket, res) THEN RETURN FALSE END;
		IF ~EnetUdp.SetDestination(transfer.socket, transfer.remoteAdr, transfer.remotePort, blockingCompletion, res) THEN RETURN FALSE END;
		IF res = EnetBase.OpInProgress THEN
			WHILE ~blockingCompletion.param(Boolean).value & EnetInterfaces.UpdateAll(res) DO END
		END;
		IF res # 0 THEN RETURN FALSE END;

		transfer.remLength := length;
		transfer.block := 0;
		transfer.op := OpRequestWrite;

		(* Send WRQ *)
		WriteRequest(OpRequestWrite, name, mode, transfer.data, transfer.dataLength);
		transfer.state := WaitForAck;
		IF ~EnetUdp.Send(transfer.socket, transfer.data, 0, transfer.dataLength, {}, NIL, res) THEN RETURN FALSE END;
		RETURN TRUE
	END WriteFile;

	(**
		Start receiving file 'name' with mode 'mode' from host 'source'.
		The receiver 'handler' is called on all received data buffers.
	*)
	PROCEDURE ReadFile * (VAR transfer: Transfer; CONST name, mode: ARRAY OF CHAR; CONST source: EnetBase.IpAddr; handler: DataReceiveHandler; handlerParam: ANY; VAR res: EnetBase.Int): BOOLEAN;
	BEGIN
		res := 0;
		(* Transfer must not be used *)
		IF transfer = NIL THEN
			NEW(transfer);
			NEW(transfer.timeoutTask);
			transfer.next := transfers;
			transfers := transfer
		END;
		transfer.handler := handler;
		transfer.handlerParam := handlerParam;
		IF (transfer.state # Idle) & (transfer.state # Error) THEN res := TransferBusy; RETURN FALSE END;

		(* Setup UDP layer *)
		transfer.remoteAdr := source;
		transfer.remotePort := TftpPort;
		IF (transfer.socket = NIL) THEN
			transfer.localPort := GetLocalPort();
			IF ~EnetUdp.NewSocket(transfer.socket, transfer.localPort, res) THEN RETURN FALSE END;
			IF ~EnetUdp.SetRecvHandler(transfer.socket, HandlePacket, res) THEN RETURN FALSE END
		END;
		blockingCompletion := GetBlockingCompletion();
		IF ~EnetUdp.SetDestination(transfer.socket, transfer.remoteAdr, transfer.remotePort, blockingCompletion, res) THEN RETURN FALSE END;
		IF res = EnetBase.OpInProgress THEN
			WHILE ~blockingCompletion.param(Boolean).value & EnetInterfaces.UpdateAll(res) DO END
		END;
		IF res # 0 THEN RETURN FALSE END;
		IF Trace THEN EnetTrace.StringLn("EnetTftp: Found read source, initiating transfer") END;

		transfer.timeoutTask.param := transfer;
		transfer.timeoutTask.handle := TimeoutHandler;
		transfer.remLength := 0;
		transfer.block := 0;
		transfer.op := OpRequestWrite;

		(* Send RRQ *)
		WriteRequest(OpRequestRead, name, mode, transfer.data, transfer.dataLength);
		transfer.block := 1;
		transfer.state := WaitForData;
		transfer.retries := 0;
		IF ~SendWithTimeout(transfer, res) THEN RETURN FALSE END;
		RETURN TRUE
	END ReadFile;

	(**
		Send file data for the transfer.
		Can be called multiple times per transfer.
		Transfer is automatically terminated when its remaining length has reached 0
	*)
	PROCEDURE SendData * (transfer: Transfer; CONST buf: ARRAY OF CHAR; ofs, len: EnetBase.Int; completionHandler: EnetBase.TaskHandler; VAR res: EnetBase.Int): BOOLEAN;
	VAR
		blockLen, i: EnetBase.Int;
	BEGIN
		IF len > transfer.remLength THEN NotifyError(transfer, TooMuchData, FALSE, FALSE); RETURN FALSE END;
		FOR i := 0 TO len DIV DataTxLen DO
			WHILE (transfer.state = WaitForAck) & EnetInterfaces.UpdateAll(res) DO END;
			IF (res # 0) THEN
				NotifyError(transfer, res, FALSE, FALSE);
				RETURN FALSE
			ELSIF transfer.state # WaitForUser THEN
				ASSERT(transfer.state = Error);
				res := transfer.res;
				RETURN FALSE
			END;
			blockLen := MIN(DataTxLen, len);
			DEC(transfer.remLength, blockLen);

			transfer.data[0] := CHR(OpData DIV 100H MOD 100H);
			transfer.data[1] := CHR(OpData MOD 100H);
			transfer.data[2] := CHR(transfer.block DIV 100H MOD 100H);
			transfer.data[3] := CHR(transfer.block MOD 100H);
			IF blockLen # 0 THEN
				SYSTEM.MOVE(ADDRESSOF(buf[ofs]), ADDRESSOF(transfer.data[4]), blockLen)
			END;
			transfer.dataLength := blockLen + HeaderLength;
			transfer.retries := 0;
			IF ~SendWithTimeout(transfer, res) THEN NotifyError(transfer, res, FALSE, FALSE); RETURN FALSE END;

			transfer.state := WaitForAck;
			INC(ofs, blockLen);
			DEC(len, blockLen)
		END;
		res := transfer.res;
		RETURN transfer.state # Error
	END SendData;

	(**
		Get error string from TFTP error code.
	*)
	PROCEDURE GetErrorString * (code: EnetBase.Int; VAR str: ARRAY OF CHAR);
	BEGIN
		CASE code OF
			 FileNotFound: str := "File not found"
			|AccessViolation: str := "Access violation"
			|DiskFull: str := "DiskFull"
			|IllegalOperation: str := "IllegalOperation"
			|UnknownTransferId: str := "Unknown transfer id"
			|FileAlreadyExists: str := "File already exists"
			|NoSuchUser: str := "No such user"
		ELSE
			str := ""
		END
	END GetErrorString;

	(**
		Initialize a reader on a file transfer.
		'reader' is the reader. It must be allocated.
		'transfer' is the TFTP transfer.
		'name' is the file name.
		'mode' is the TFTP transfer mode (octet, netascii or mail).
		'source' is the TFTP server IP address.
		'bufferSize' is the stream internal buffer size.
	*)
	PROCEDURE InitReader * (reader: EnetStreams.Reader; VAR transfer: Transfer; CONST name, mode: ARRAY OF CHAR; CONST source: EnetBase.IpAddr; bufferSize: EnetBase.Int): BOOLEAN;
	VAR
		ok: BOOLEAN;
	BEGIN
		ASSERT(reader # NIL);
		EnetStreams.InitReader(reader^, bufferSize, transfer);
		ok := ReadFile(transfer, name, mode, source, StreamReceiveHandler, reader, reader.res);
		IF ok THEN reader.res := 0 END;
		RETURN ok
	END InitReader;

	(**
		Initialize a writer on a file transfer.
		'writer' is the stream. It must be allocated.
		'transfer' is the TFTP transfer descriptor.
		'name' is the file name.
		'mode' is the TFTP transfer mode.
		'dest' is the TFTP server address.
		'bufferSize' is the internal stream buffer size.
		'length' is the total length of the transmitted file.
	*)
	PROCEDURE InitWriter * (writer: EnetStreams.Writer; VAR transfer: Transfer; CONST name, mode: ARRAY OF CHAR; CONST dest: EnetBase.IpAddr; bufferSize, length: EnetBase.Int): BOOLEAN;
	BEGIN
		ASSERT(writer # NIL);
		EnetStreams.InitWriter(writer^, bufferSize, transfer, {}, SendFromWriter);
		RETURN WriteFile(transfer, name, mode, length, dest, writer.res)
	END InitWriter;

	(** Handle reception of a TFTP packet *)
	PROCEDURE HandlePacket (socket: EnetUdp.Socket; CONST remoteAdr: EnetBase.IpAddr; remotePort: EnetBase.Int; VAR data: ARRAY OF CHAR; dataOfs, dataLen: EnetBase.Int; packet: EnetBase.Packet);
	VAR
		transfer: Transfer;
		res, opcode, block, sendLength: EnetBase.Int;
	BEGIN
		(* Get transfer *)
		transfer := GetTransferBySocket(socket);
		ASSERT(transfer # NIL);
		IF Trace THEN EnetTrace.StringLn("EnetTftp: Received TFTP packet") END;

		(* Check remote address and port consistency *)
		IF remoteAdr # transfer.remoteAdr THEN
			IF Trace THEN EnetTrace.StringLn("EnetTftp: Packet not from remote host") END;
			RETURN
		END;
		IF (transfer.remotePort # TftpPort) & (remotePort # transfer.remotePort) THEN
			(* Not the first data packet of a receive: not allowed to change port *)
			IF Trace THEN EnetTrace.StringLn("EnetTftp: Packet not from remote port") END;
			RETURN
		END;
		(* ACK of request specifies new transaction port *)
		IF remotePort # transfer.remotePort THEN
			IF Trace THEN EnetTrace.StringLn("EnetTftp: Updating remote port: " & transfer.remotePort & " -> " & remotePort) END;
			transfer.remotePort := remotePort;
			blockingCompletion := GetBlockingCompletion();
			IF ~EnetUdp.SetDestination(transfer.socket, transfer.remoteAdr, transfer.remotePort, blockingCompletion, res) THEN
				NotifyError(transfer, res, TRUE, FALSE);
				RETURN
			END;
			IF res = EnetBase.OpInProgress THEN
				WHILE ~blockingCompletion.param(Boolean).value & EnetInterfaces.UpdateAll(res) DO END
			END
		END;

		(* Transfer must be waiting for data or for ack *)
		IF (transfer.state # WaitForData) & (transfer.state # WaitForAck) THEN
			IF Trace THEN EnetTrace.StringLn("EnetTftp: Tx is not waiting for packet (" & transfer.state & ")") END;
			RETURN
		END;
		EnetBase.RemoveTask(transfer.socket.intf, transfer.timeoutTask);
		GetHeader(data, dataOfs, opcode, block);

		IF opcode = OpError THEN
			IF Trace THEN EnetTrace.StringLn("EnetTftp: Received error message: " & block) END;
			NotifyError(transfer, block, transfer.state = WaitForData, FALSE);
			RETURN
		ELSIF transfer.state = WaitForData THEN
			IF (opcode # OpData) THEN
				IF Trace THEN EnetTrace.StringLn("EnetTftp: Opcode is not 'data': " & opcode) END;
				NotifyError(transfer, IllegalOperation, TRUE, TRUE);
				RETURN
			END;
			IF (block # transfer.block) THEN
				IF Trace THEN EnetTrace.StringLn("EnetTftp: Block # is not as expected (" & block & " instead of " & transfer.block & ")") END;
				NotifyError(transfer, IllegalOperation, TRUE, TRUE);
				RETURN
			END;

			WriteAck(transfer.block, transfer.data, sendLength);
			IF dataLen - HeaderLength < DataTxLen THEN
				(* Last packet: send an ack without waiting for next packet *)
				IF ~EnetUdp.Send(transfer.socket, transfer.data, 0, sendLength, {}, blockingCompletion, res) THEN
					NotifyError(transfer, res, TRUE, FALSE);
					RETURN
				END;
				transfer.state := Idle;
			ELSE
				(* Other packets to receive: use timeout *)
				transfer.dataLength := sendLength;
				transfer.retries := 0;
				IF ~SendWithTimeout(transfer, res) THEN
					NotifyError(transfer, res, TRUE, FALSE);
					RETURN
				END;
				INC(transfer.block)
			END;
			(* Call handler *)
			INC(packet.payloadOffs, HeaderLength);
			transfer.handler(transfer, data, dataOfs + HeaderLength, dataLen - HeaderLength, 0, packet, dataLen - HeaderLength < DataTxLen)

		ELSE
			(* Waiting for ACK *)
			IF opcode # OpAck THEN
				IF Trace THEN EnetTrace.StringLn("EnetTftp: Opcode is not 'ack' (" & opcode & ")") END;
				NotifyError(transfer, IllegalOperation, FALSE, TRUE);
				RETURN
			END;
			IF (block # transfer.block) THEN
				IF Trace THEN EnetTrace.StringLn("EnetTftp: Block # is not as expected (" & block & " instead of " & transfer.block & ")") END;
				NotifyError(transfer, IllegalOperation, FALSE, TRUE);
				RETURN
			END;

			IF transfer.remLength > 0 THEN
				IF Trace THEN EnetTrace.StringLn("EnetTftp: Still " & transfer.remLength & " B to transfer") END;
				transfer.state := WaitForUser
			ELSE
				IF Trace THEN EnetTrace.StringLn("EnetTftp: Transfer finished") END;
				transfer.state := Idle
			END;
			INC(transfer.block)
		END
	END HandlePacket;

	(** Handle Timeout *)
	PROCEDURE TimeoutHandler (handler: EnetBase.TaskHandler);
	VAR
		transfer: Transfer;
		res: EnetBase.Int;
	BEGIN
		transfer := handler.param(Transfer);
		IF ((transfer.state = WaitForData) OR (transfer.state = WaitForAck)) THEN
			IF Trace THEN EnetTrace.StringLn("EnetTftp: Timeout") END;
			IF transfer.retries = MaxRetries THEN
				IF Trace THEN EnetTrace.StringLn("EnetTftp: Max number of retries exceeded, transfer error") END;
				NotifyError(transfer, TimeoutExpired, TRUE, FALSE);
				RETURN
			END;
			INC(transfer.retries);
			IF ~SendWithTimeout(transfer, res) THEN
				NotifyError(transfer, TimeoutExpired, TRUE, FALSE);
				RETURN
			END
		END
	END TimeoutHandler;

	(** Sends a packet for a transfer with a timeout for reception *)
	PROCEDURE SendWithTimeout (transfer: Transfer; VAR res: EnetBase.Int): BOOLEAN;
	BEGIN
		IF Trace THEN EnetTrace.StringLn("EnetTftp: Sending packet (" & transfer.dataLength & " B)") END;
		EnetBase.ScheduleTask(transfer.socket.intf, transfer.timeoutTask, FALSE, timeout);
		RETURN EnetUdp.Send(transfer.socket, transfer.data, 0, transfer.dataLength, {}, NIL, res)
	END SendWithTimeout;

	(** Sets the transfer error state to 'res'. *)
	PROCEDURE NotifyError (transfer: Transfer; res: EnetBase.Int; doHandle, sendErrorMsg: BOOLEAN);
	VAR
		ignoreRes: EnetBase.Int;
		ignore: BOOLEAN;
	BEGIN
		transfer.res := res;
		transfer.state := Error;
		IF doHandle THEN transfer.handler(transfer, transfer.data, 0, 0, res, NIL, TRUE) END;
		IF sendErrorMsg THEN
			transfer.data[0] := CHR(OpError DIV 100H MOD 100H);
			transfer.data[1] := CHR(OpError MOD 100H);
			transfer.data[2] := CHR(res DIV 100H MOD 100H);
			transfer.data[3] := CHR(res MOD 100H);
			transfer.data[4] := 0X;
			ignore := EnetUdp.Send(transfer.socket, transfer.data, 0, 5, {}, NIL, ignoreRes)
		END
	END NotifyError;

	PROCEDURE GetHeader(CONST data: ARRAY OF CHAR; ofs: EnetBase.Int; VAR opcode, block: EnetBase.Int);
	BEGIN
		opcode := ORD(data[ofs]) * 100H + ORD(data[ofs + 1]); INC(ofs, 2);
		block := ORD(data[ofs]) * 100H + ORD(data[ofs + 1])
	END GetHeader;

	PROCEDURE WriteRequest (opcode: EnetBase.Int; CONST filename, mode: ARRAY OF CHAR; VAR packet: ARRAY OF CHAR; VAR length: EnetBase.Int);
	BEGIN
		ASSERT((opcode = OpRequestRead) OR (opcode = OpRequestWrite));
		ASSERT(filename # '');
		ASSERT((mode = ModeNetAscii) OR (mode = ModeOctet) OR (mode = ModeMail));
		length := 0;
		packet[length] := CHR(opcode DIV 100H MOD 100H); INC(length);
		packet[length] := CHR(opcode MOD 100H); INC(length);
		CopyString(filename, packet, length);
		packet[length] := 0X; INC(length);
		CopyString(mode, packet, length);
		packet[length] := 0X; INC(length)
	END WriteRequest;

	PROCEDURE WriteAck (block: EnetBase.Int; VAR packet: ARRAY OF CHAR; VAR length: EnetBase.Int);
	BEGIN
		length := 0;
		packet[length] := CHR(OpAck DIV 100H MOD 100H);
		packet[length + 1] := CHR(OpAck MOD 100H); INC(length, 2);
		packet[length] := CHR(block DIV 100H MOD 100H);
		packet[length + 1] := CHR(block MOD 100H); INC(length, 2)
	END WriteAck;

	PROCEDURE GetTransferBySocket (socket: EnetUdp.Socket): Transfer;
	VAR
		cur: Transfer;
	BEGIN
		cur := transfers;
		WHILE (cur # NIL) & (cur.socket # socket) DO cur := cur.next END;
		RETURN cur
	END GetTransferBySocket;

	PROCEDURE CopyString (CONST src: ARRAY OF CHAR; VAR dest: ARRAY OF CHAR; VAR destOfs: EnetBase.Int);
	VAR
		len: EnetBase.Int;
	BEGIN
		len := 0;
		WHILE src[len] # 0X DO INC(len) END;
		IF len >= LEN(dest) THEN len := LEN(dest) END;
		SYSTEM.MOVE(ADDRESSOF(src[0]), ADDRESSOF(dest[destOfs]), len);
		INC(destOfs, len)
	END CopyString;

	PROCEDURE GetBlockingCompletion (): EnetBase.TaskHandler;
	VAR
		b: Boolean;
	BEGIN
		IF blockingCompletion = NIL THEN
			NEW(blockingCompletion);
			NEW(b);
			blockingCompletion.handle := BlockingCompletion;
			blockingCompletion.param := b;
		END;
		blockingCompletion.param(Boolean).value := FALSE;
		RETURN blockingCompletion
	END GetBlockingCompletion;

	PROCEDURE GetLocalPort (): LONGINT;
	VAR
		port: LONGINT;
	BEGIN
		port := lastPort;
		INC(lastPort);
		IF lastPort > LocalPortMax THEN lastPort := LocalPortMin END;
		RETURN port
	END GetLocalPort;

	PROCEDURE BlockingCompletion (t: EnetBase.TaskHandler);
	BEGIN
		t.param(Boolean).value := TRUE
	END BlockingCompletion;

	PROCEDURE StreamReceiveHandler (transfer: Transfer; VAR buffer: ARRAY OF CHAR; ofs, len, res: EnetBase.Int; packet: EnetBase.Packet; end: BOOLEAN);
	BEGIN
		IF end THEN
			transfer.handlerParam(EnetStreams.Reader).enetEndOfStream := TRUE
		END;
		IF res = 0 THEN
			packet.ownedByUser := TRUE;
			ASSERT(EnetBase.PacketFifoPut(transfer.handlerParam(EnetStreams.Reader).enetPackets, packet))
		END
	END StreamReceiveHandler;

	PROCEDURE SendFromWriter (access: ANY; CONST buf: ARRAY OF CHAR; ofs, len: LONGINT; flags: SET; VAR res: LONGINT);
	VAR
		ignore: BOOLEAN;
	BEGIN
		ignore := SendData(access(Transfer), buf, ofs, len, NIL, res)
	END SendFromWriter;

	PROCEDURE Init;
	BEGIN
		lastPort := LocalPortMin;
		timeout := EnetTiming.fromMilli(Timeout)
	END Init;
BEGIN 
	Init
END EnetTftp.
