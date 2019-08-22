MODULE EnetStreams;
(**
	AUTHOR: Timothée Martiel, HighDim GmbH, 2015
	PURPOSE: Ethernet networking stack stream interface for MINOS
*)

IMPORT
	SYSTEM,
	StreamReaders, StreamWriters,
	EnetBase, EnetInterfaces;

TYPE
	Reader * = POINTER TO ReaderDesc;
	ReaderDesc * = RECORD (StreamReaders.Reader)
		enetAccess *: ANY;
		enetPackets *: EnetBase.PacketFifo;
		enetPacket: EnetBase.Packet;
		enetPacketOffset: EnetBase.Int;
		enetEndOfStream *: BOOLEAN;
	END;

	Sender * = PROCEDURE (access: ANY; CONST buf: ARRAY OF CHAR; ofs, len: EnetBase.Int; flags: SET; VAR res: EnetBase.ResultCode);

	Writer * = POINTER TO WriterDesc;
	WriterDesc * = RECORD (StreamWriters.Writer)
		enetAccess: ANY;
		enetFlags: SET;
		enetSend: Sender;
	END;

	PROCEDURE InitReader * (VAR reader: ReaderDesc; bufferSize: EnetBase.Int; access: ANY);
	BEGIN
		StreamReaders.Init(reader, Receive, bufferSize);
		reader.enetAccess := access;
		reader.enetPackets := EnetBase.NewPacketFifo(10);
		reader.enetPacketOffset := 0;
		reader.enetEndOfStream := FALSE
	END InitReader;

	PROCEDURE InitWriter * (VAR writer: WriterDesc; bufferSize: EnetBase.Int; access: ANY; flags: SET; sender: Sender);
	BEGIN
		StreamWriters.Init(writer, Send, bufferSize);
		writer.enetAccess := access;
		writer.enetFlags := flags;
		writer.enetSend := sender
	END InitWriter;

	PROCEDURE Receive * (VAR reader: StreamReaders.Reader; VAR buf: ARRAY OF CHAR;  ofs, size, min: EnetBase.Int;  VAR len: EnetBase.Int; VAR res: EnetBase.ResultCode);
	VAR
		packet: EnetBase.Packet;
		pktOfs, cpLen: EnetBase.Int;
	BEGIN
		WITH reader: ReaderDesc DO
			packet := reader.enetPacket;
			len := 0;
			LOOP
				IF res > 0 THEN EXIT
				ELSIF size = 0 THEN EXIT
				ELSIF (packet = NIL) THEN
					REPEAT
						IF ~EnetInterfaces.UpdateAll(res) THEN EXIT END
					UNTIL EnetBase.PacketFifoGet(reader.enetPackets, packet) OR reader.enetEndOfStream OR (len >= min);
					IF res # 0 THEN EXIT
					ELSIF reader.enetEndOfStream & (packet = NIL) THEN
						reader.enetPacket := NIL;
						IF len = 0 THEN res := StreamReaders.EOF END;
						EXIT
					ELSIF (packet = NIL) & (len >= min) THEN
						reader.enetPacket := NIL;
						EXIT
					ELSE
						reader.enetPacketOffset := 0
					END;
					ASSERT(packet # NIL)
				ELSE
					pktOfs := packet.dataOffs + packet.payloadOffs + reader.enetPacketOffset;
					cpLen := MIN(size, packet.dataLen - packet.payloadOffs - reader.enetPacketOffset);
					SYSTEM.MOVE(ADDRESSOF(packet.data[pktOfs]), ADDRESSOF(buf[ofs]), cpLen);
					DEC(size, cpLen);
					INC(ofs, cpLen);
					INC(len, cpLen);
					IF cpLen = packet.dataLen - packet.payloadOffs - reader.enetPacketOffset THEN
						reader.enetPacketOffset := 0;
						packet.ownedByUser := FALSE;
						IF ~EnetBase.ReturnPacketToOwnerPool(packet) THEN res := -1; EXIT END;
						packet := NIL;
					ELSE
						reader.enetPacket := packet;
						reader.enetPacketOffset := cpLen + pktOfs - packet.dataOffs - packet.payloadOffs;
						EXIT
					END
				END
			END
		END
	END Receive;

	PROCEDURE Send (VAR writer: StreamWriters.Writer; CONST buf: ARRAY OF CHAR;  ofs, len: EnetBase.Int;  propagate: BOOLEAN; VAR res: EnetBase.ResultCode);
	BEGIN
		WITH writer: WriterDesc DO
			writer.enetSend(writer.enetAccess, buf, ofs, len, writer.enetFlags, res)
		END;
		IF res = EnetBase.OpInProgress THEN res := StreamWriters.Ok END
	END Send;
END EnetStreams.
