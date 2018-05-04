MODULE EnetUdpChannels;
(*
	AUTHOR: Timothée Martiel
	PURPOSE: Channels over UDP that ensure communication with a single remote host.
*)
IMPORT Trace, EnetBase, EnetInterfaces, EnetUdp, EnetStreams;

CONST
	ErrUnboundChannel * = 100;

TYPE
	(**
		Channel descriptor.
		A channel is based on a socket. It uses only those packets from the socket that come from the channel's remote port.
	*)
	Channel * = POINTER TO ChannelDesc;
	ChannelDesc * = RECORD
		socket: EnetUdp.Socket;					(** Underlying socket *)
		remoteIp *: EnetBase.IpAddr;				(** IP address of the remote host *)
		remotePort *: EnetBase.Int;				(** UDP port of the remote host *)
		channelHandler: RecvDatagramHandler;	(** Channel receiver callback *)
		channelHandlerParam *: ANY;			(** Channel receiver callback parameter *)
		next: Channel;								(** Next channel based on the same socket *)
	END;

	(** Channel datagram receiver. The datagram is guaranteed to come from the channel's remote IP and remote port. *)
	RecvDatagramHandler * = PROCEDURE {DELEGATE} (channel: Channel; VAR data: ARRAY OF CHAR; dataOffs, dataLen: EnetBase.Int; packet: EnetBase.Packet);

VAR
	handler: EnetBase.TaskHandler;

	(**
		Opens a new channel on 'socket'. The socket cannot be used in another way than with channels.
		If remoteIP is not a valid IP address, the first datagram received on the socket will bind the channel to its sender.
	*)
	PROCEDURE NewChannel * (VAR channel: Channel; socket: EnetUdp.Socket; remoteIp: EnetBase.IpAddr; remotePort: EnetBase.Int; VAR result: EnetBase.Int): BOOLEAN;
	VAR
		ch: ANY;
	BEGIN
		NEW(channel);
		channel.socket := socket;
		ch := socket.recvHandlerParam;
		IF ch = NIL THEN
			socket.recvHandlerParam := channel
		ELSE
			WITH ch: Channel DO
				WHILE ch.next # NIL DO ch := ch.next END;
				ch.next := channel
			END
		END;
		IF ~EnetBase.IsValidIpAddr(remoteIp) & (remotePort < 0) THEN RETURN FALSE END;
		channel.remoteIp := remoteIp;
		channel.remotePort := remotePort;
		IF ~EnetUdp.SetRecvHandler(socket, HandlePacket, result) THEN RETURN FALSE END;
		RETURN TRUE
	END NewChannel;

	(** Changes the receiver callback of a channel *)
	PROCEDURE SetReceiveHandler * (channel: Channel; handler: RecvDatagramHandler);
	BEGIN
		channel.channelHandler := handler
	END SetReceiveHandler;

	(** Send the [data[ofs], data[ofs + len]) on the channel. Send can only succeed on a bound channel. *)
	PROCEDURE Send * (channel: Channel; CONST data: ARRAY OF CHAR; ofs, len: EnetBase.Int; flags: SET; completionHandler: EnetBase.TaskHandler; VAR res: EnetBase.Int): BOOLEAN;
	BEGIN
		IF ~EnetBase.IsValidIpAddr(channel.remoteIp) OR (channel.remotePort < 0) THEN res := ErrUnboundChannel; RETURN FALSE END;
		RETURN EnetUdp.SendTo(channel.socket, channel.remoteIp, channel.remotePort, data, ofs, len, flags, completionHandler, res)
	END Send;

	(** Opens a Enet reader on the channel, with the specified buffer size *)
	PROCEDURE InitReader * (reader: EnetStreams.Reader; bufferSize: EnetBase.Int; channel: Channel);
	BEGIN
		ASSERT(reader # NIL);
		EnetStreams.InitReader(reader^, bufferSize, channel);
		channel.channelHandlerParam := reader;
		SetReceiveHandler(channel, StreamReceiveHandler)
	END InitReader;

	(** Opens an Enet writer on a channel, with the given send flags and the given buffer size *)
	PROCEDURE InitWriter * (writer: EnetStreams.Writer; bufferSize: EnetBase.Int; flags: SET; channel: Channel);
	BEGIN
		ASSERT(writer # NIL);
		EnetStreams.InitWriter(writer^, bufferSize, channel, flags, SendFromStreamWriter)
	END InitWriter;

	PROCEDURE HandlePacket (socket: EnetUdp.Socket; CONST srcAddr: EnetBase.IpAddr; srcPort: EnetBase.Int; VAR data: ARRAY OF CHAR; dataOffs, dataLen: EnetBase.Int; packet: EnetBase.Packet);
	VAR
		channel: Channel;
		res: EnetBase.Int;
	BEGIN
		channel := socket.recvHandlerParam(Channel);
		WHILE (channel # NIL) &
				((((channel.remoteIp # srcAddr) & EnetBase.IsValidIpAddr(channel.remoteIp))
				OR ((channel.remotePort # srcPort) & (channel.remotePort >= 0)))) DO
			channel := channel.next
		END;
		IF channel # NIL THEN
			IF ~EnetBase.IsValidIpAddr(channel.remoteIp) THEN
				(* Channel is not bound yet *)
				ASSERT(channel.remotePort = srcPort);
				channel.remoteIp := srcAddr;
				IF handler = NIL THEN
					NEW(handler)
				END;
				handler.param := NIL;
				handler.handle := BlockingCompletionHandler;
				ASSERT(EnetUdp.SetDestination(channel.socket, srcAddr, srcPort, handler, res));
				IF res = EnetBase.OpInProgress THEN
					WHILE EnetInterfaces.UpdateAll(res) & (handler.param = NIL) DO END
				END;
				ASSERT(res = 0)
			END;
			IF channel.remotePort < 0 THEN
				ASSERT(channel.remoteIp = srcAddr);
				channel.remotePort := srcPort
			END;
			IF channel.channelHandler # NIL THEN channel.channelHandler(channel, data, dataOffs, dataLen, packet) END
		END
	END HandlePacket;

	PROCEDURE StreamReceiveHandler (channel: Channel; VAR data: ARRAY OF CHAR; dataOffs, dataLen: EnetBase.Int; packet: EnetBase.Packet);
	BEGIN
		packet.ownedByUser := TRUE;
		ASSERT(EnetBase.PacketFifoPut(channel.channelHandlerParam(EnetStreams.Reader).enetPackets, packet))
	END StreamReceiveHandler;

	PROCEDURE SendFromStreamWriter (access: ANY; CONST buf: ARRAY OF CHAR; ofs, len: LONGINT; flags: SET; VAR res: LONGINT);
	VAR
		ignore: BOOLEAN;
	BEGIN
		WITH access: Channel DO
			ignore := Send(access, buf, ofs, len, flags, NIL, res)
		END
	END SendFromStreamWriter;

	PROCEDURE BlockingCompletionHandler (handler: EnetBase.TaskHandler);
	BEGIN
		handler.param := handler
	END BlockingCompletionHandler;
END EnetUdpChannels.