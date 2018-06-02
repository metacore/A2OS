(* Copyright 2005-2006, Markus Heule, ETH Zurich *)

MODULE OSCNet;  (** AUTHOR "heulemar"; PURPOSE "OpenSoundControl networkplugins (TCP and UDP)"; *)

(*

This modue contains objecttypes for the TCP and UDP implementation of the OSC protocol. For each version, a server
and a client version is supplied.

The server version uses an OSCService as servicebackend. Upon creation of a serverobject, it will
start listening for connections or packets from the network. When it receives a packet, it parses it and upon successful
parsing, it will hand it over to the corresponding OSCService. They can also return packets to the sender of another
packet with the 'Return' function. The services can be stopped with the 'Stop' function.

Note: The TCP version uses the TCPServices framework to support multiple concurrent TCP connections.

Example of usage:

VAR
	net: OSCNet.OSCUDPServer or OSCNet.OSCTCPServer;
	service: OSCService.OSCService;
BEGIN
	...
	NEW(net, service, 57110, res); (* server listens now on port 57110 and delivers packets to service *)
	...
	net.Stop; (* stopps the networkplugin *)
	...


The client versions can send OSCPackets to a remote OSCServer. They can also receive replies from the remote OSC server.

Example:

VAR
	client: OSCTCPClient (or OSCUDPClient);
	p, newp: OSCPacket;
	res: WORD;
BEGIN
	NEW(client, fip, fport, TCP.NilPort, res);
	...
	res := client.Send(p);
	...
	res := client.Receive(newp);
*)

IMPORT
	OSC, OSCService, IP, UDP, TCP, Network, TCPServices,
	Kernel, KernelLog (* Testing *), Strings;

CONST

	Ok* = 0;
	Timeout* = 4401;
	ParseError* = 4402;
	PacketTooBig* = 4403;
	BadReturnData* = 4404;

	MaxUDPPacketLength* = 10000H;
	MaxTCPPacketLength = MaxUDPPacketLength; (* TOOD: What value? *)
	ReceiveTimeout* = 1000; (* ms *)

	NotImplemented* = 101;

	Trace* = FALSE;
	UDPHack = TRUE;


TYPE
	(* abstract class of all network clients *)
	OSCClient = OBJECT
		PROCEDURE Send*(p: OSC.OSCPacket): LONGINT;
		BEGIN HALT(NotImplemented); END Send;

		PROCEDURE Receive*(VAR p: OSC.OSCPacket): LONGINT;
		BEGIN HALT(NotImplemented); END Receive;

		PROCEDURE Close*;
		BEGIN HALT(NotImplemented); END Close;
	END OSCClient;

	(* This objecttype is used to store the IP and the Port of the remote client.
		This information is used when a packet should be returned to a sender. (See SetReturner(..) in OSCUDPServer) *)
	OSCUDPData = OBJECT
		VAR
			fip*: IP.Adr;
			fport*: LONGINT;
	END OSCUDPData;

	(* UDP Client *)
	OSCUDPClient* = OBJECT(OSCClient)
		VAR
			s: UDP.Socket;
			fip: IP.Adr;
			fport: LONGINT;

		(* Creates a new UDPClient which sends packets to fip:fport.
			Supply UDP.NilPort for lport, if you don't want to specify a fixed local port for communication.
			In res the returnvalue of the UDP.Socket's creations is returned. If res doesn't equal to UDP.Ok, the
			client shouldn't be used *)
		PROCEDURE &InitUDP*(fip: IP.Adr; fport, lport: LONGINT; VAR res: WORD);
		BEGIN
			SELF.fip := fip;
			SELF.fport := fport;
			NEW(s, lport, res);
		END InitUDP;

		(* sends an OSCMessage or an OSCBundle to fip:fport. Returns the statuscode of UDP.Socket.Send *)
		PROCEDURE Send*(p: OSC.OSCPacket): LONGINT;
		BEGIN
			RETURN SendUDP(s, fip, fport, p);
		END Send;

		(* receives a packet from the network. Only UDP packets from our partner are considered.
			You can also supply a timeout in miliseconds. Use -1 for a infinite wait.
			Returns Ok, ParseError or an UDP returncode (eg:. UDP.Timeout) *)
		PROCEDURE Recieve*(VAR p: OSC.OSCPacket; timeout (* in ms *): LONGINT): LONGINT;
		VAR
			fip2: IP.Adr; fport2: LONGINT;
			size: LONGINT;
			buffer: Strings.String;
			got, res: LONGINT;
			endticks: LONGINT;
			istimeout: BOOLEAN;
		BEGIN
			IF timeout # -1 THEN
				(* timeout *)
				istimeout := TRUE;
				endticks := Kernel.GetTicks () + timeout;
			END;
			NEW(buffer, MaxUDPPacketLength);
			REPEAT
				IF istimeout THEN timeout := endticks - Kernel.GetTicks (); END;
				s.Receive(buffer^, 0, MaxUDPPacketLength, timeout, fip2, fport2, got, res);
			UNTIL (res # UDP.Ok) OR (IP.AdrsEqual(fip, fip2) & (fport = fport2));
			IF res # UDP.Ok THEN RETURN res; END;
			(* parse packet *)
			size := got;
			p := OSC.ParseOSCPacket(buffer^, size);
			IF p = NIL THEN RETURN ParseError; END;
			RETURN Ok;
		END Recieve;

		(* closes the clientconnection *)
		PROCEDURE Close*;
		BEGIN
			s.Close();
		END Close;

	END OSCUDPClient;


	(* UDP Server *)
	OSCUDPServer* = OBJECT
		VAR
			s: UDP.Socket;
			serror: BOOLEAN;
			oscservice: OSCService.OSCService;
			stopping: BOOLEAN; (* flag to stop the service *)

			(* inernal variables of 'main'-procedure *)
			newPacket: OSC.OSCPacket;
			newUDPData: OSCUDPData;
			buffer: OSC.String; (* ARRAY MaxUDPPacketLength OF CHAR; *)
			receivefip: IP.Adr; receivefport: LONGINT;
			got, res: LONGINT;

		(* Sets the signal to stop the service *)
		PROCEDURE Stop*;
		BEGIN { EXCLUSIVE }
			stopping := TRUE;
		END Stop;

		(* Creates a new UDPServer listening on UDP port lport.. Sends received packets to service.
			If res is not UDP.Ok, then the server will immediately quit *)
		PROCEDURE &InitUDPServer*(service: OSCService.OSCService; lport: LONGINT; VAR res: WORD);
		BEGIN
			ASSERT(service # NIL);
			oscservice := service;
			NEW(buffer, MaxUDPPacketLength);
			NEW(s, lport, res);
			IF(res # UDP.Ok) THEN serror := TRUE; ELSE serror := FALSE; END;
			stopping := FALSE;
		END InitUDPServer;

		(* Returns an OSCMessage or an OSCBundle to the sender specified by data, which is indeed an instance of OSCUDPData *)
		PROCEDURE return(p: OSC.OSCPacket; data: OBJECT): LONGINT;
		BEGIN
			IF data IS OSCUDPData THEN
				WITH data: OSCUDPData DO
					IF Trace THEN KernelLog.String('UDPServer.Return called'); KernelLog.Ln;
						IP.OutAdr(data.fip); KernelLog.String(' Port: '); KernelLog.Int(data.fport, 10);
						KernelLog.Ln; END;
					RETURN SendUDP(s, data.fip, data.fport, p);
				END;
			ELSE
				IF Trace THEN KernelLog.String('UDPServer.Return: BadReturnData received'); KernelLog.Ln; END;
				RETURN BadReturnData;
			END;
		END return;

	BEGIN { ACTIVE }
		IF (~serror) THEN
			REPEAT
				(* receive packets and parse them *)
				s.Receive(buffer^, 0, MaxUDPPacketLength, ReceiveTimeout, receivefip, receivefport, got, res);
				IF res = UDP.Ok THEN
					newPacket := OSC.ParseOSCPacket(buffer^, got);
					IF newPacket # NIL THEN
						NEW(newUDPData);
						IF Trace THEN
							KernelLog.String('OSCUDPServer: Received Packet from: '); KernelLog.Hex(receivefip.ipv4Adr, 10);
							KernelLog.Hex(receivefip.usedProtocol, 10);
							KernelLog.Hex(receivefip.data, 10);
							KernelLog.String(' port: '); KernelLog.Int(receivefport, 10); KernelLog.Ln;
						END;
						IF UDPHack THEN
							newUDPData.fip := IP.StrToAdr('192.168.150.1');
						ELSE
							newUDPData.fip := receivefip;
						END;
						newUDPData.fport := receivefport;
						newPacket.SetReturner(return, newUDPData);
						oscservice.NewPacket(newPacket);
					END;
				ELSIF res # UDP.Timeout THEN
					(* closing service *)
					BEGIN { EXCLUSIVE }
						stopping := TRUE;
					END;
				END;
			UNTIL stopping;
			(* cleanup *)
			s.Close();
		END;
	END OSCUDPServer;

	(* TCP Client *)
	OSCTCPClient* = OBJECT(OSCClient)
		VAR
			connection: TCP.Connection;

		(* creates a new OSCTCPClient and connects to fip:fport. The user can also specify a local port to use for the outgoing
			connection. If TCP.NilPort is used, the operating system assigns a free local port number. If res doesn't euqal to
			TCP.Ok then this client shouldn't be used. *)
		PROCEDURE &InitTCP*(fip: IP.Adr; fport, lport: LONGINT; VAR res: WORD);
		BEGIN
			NEW(connection);
			connection.Open(lport, fip, fport, res);
		END InitTCP;

		PROCEDURE Close*;
		BEGIN
			connection.Close;
		END Close;

		(* sends a packet to the connected OSCServer. Returns TCP.Ok if sent successfully, otherwise an TCP.* errorcode is
			returned. *)
		PROCEDURE Send*(p: OSC.OSCPacket): LONGINT;
		BEGIN
			RETURN SendTCP(connection, p);
		END Send;

		(* receives a packet from the OSC Server. *)
		PROCEDURE Receive*(VAR p: OSC.OSCPacket): LONGINT;
		BEGIN
			RETURN ReceiveTCP(connection, p);
		END Receive;

	END OSCTCPClient;


	(* An OSCTCPServer will create for each new connection an OSCTCPAgent object. This object handles all the communication
		with the connected client. It also responsible to return messages to the sender of an OSCPacket.
		Note: The registred return-handler also includes the current SELF-pointer. Therfore, a call to returner(...) in
		OSC.OSCPacket will always be delivered to the right agent object *)
	OSCTCPAgent = OBJECT(TCPServices.Agent);
		VAR
			oscservice: OSCService.OSCService;
			newpacket: OSC.OSCPacket;
			res: WORD;

		PROCEDURE &StartOSCAgent*(oscs: OSCService.OSCService; c: TCP.Connection; s: TCPServices.Service);
		BEGIN
			ASSERT(oscs # NIL);
			oscservice := oscs;
			Start(c,s);
		END StartOSCAgent;

		(* returns a packet to the current client. data is ignored *)
		PROCEDURE return*(p: OSC.OSCPacket; data: OBJECT): LONGINT;
		BEGIN
			IF Trace THEN KernelLog.String('TCPServer.Return called IP: ');
				IP.OutAdr(client.fip); KernelLog.String(' Port: '); KernelLog.Int(client.fport, 10);
				KernelLog.Ln; END;
			RETURN SendTCP(client, p);
		END return;

	BEGIN { ACTIVE }
		LOOP
			res := ReceiveTCP(client, newpacket);
			IF res = Ok THEN
				ASSERT(newpacket # NIL);
				newpacket.SetReturner(return, NIL);
				oscservice.NewPacket(newpacket);
			ELSIF res # ParseError THEN EXIT END; (* Closing Connection on unrecoverableerror *)
		END;
		Terminate;
	END OSCTCPAgent;

	(* TCP Server *)
	OSCTCPServer* = OBJECT
		VAR
			tcpservice: TCPServices.Service;
			service: OSCService.OSCService;

		(* starts the server: registers the OSCService s and creates the TCPServices.Service, which listens for connections *)
		PROCEDURE &InitTCPServer*(s: OSCService.OSCService; lport: LONGINT; VAR res: WORD);
		BEGIN
			ASSERT(s # NIL);
			service := s;
			NEW(tcpservice, lport, newAgent, res);
		END InitTCPServer;

		(* This function is called by tcpservice to create a new agent *)
		PROCEDURE newAgent(c: TCP.Connection; s: TCPServices.Service): TCPServices.Agent;
			VAR agent: OSCTCPAgent;
		BEGIN
			NEW(agent, service, c, s);
			RETURN agent;
		END newAgent;

		(* Stops the OSCTCPServer. Closes the listening socket and all established connections *)
		PROCEDURE Stop*;
		BEGIN
			tcpservice.Stop;
		END Stop;

	END OSCTCPServer;



	PROCEDURE SendTCP(client: TCP.Connection; p: OSC.OSCPacket): LONGINT;
	VAR
		buffer: OSC.String;
		size: ARRAY 4 OF CHAR;
		res: WORD;
	BEGIN
		ASSERT(p # NIL);
		buffer := p.GetBytes();
		ASSERT(buffer # NIL);
		(* TCP: <size || packet> *)
		Network.PutNet4(size, 0, p.GetSize());
		client.Send(size, 0, 4, FALSE, res);
		IF(res # TCP.Ok) THEN RETURN res; END;
		client.Send(buffer^, 0, LEN(buffer^), FALSE, res);
		RETURN res;
	END SendTCP;

	PROCEDURE ReceiveTCP(client: TCP.Connection; VAR p: OSC.OSCPacket): LONGINT;
	VAR
		res, len: LONGINT;
		buffer: POINTER TO ARRAY OF CHAR;
		sizebuf: ARRAY 4 OF CHAR;
		packetsize: LONGINT;
	BEGIN
		client.Receive(sizebuf, 0, LEN(sizebuf), 4, len, res);
		IF res # TCP.Ok THEN RETURN res END;
		ASSERT(len = 4);
		packetsize := Network.GetNet4(sizebuf, 0);
		(* allocate new buffer *)
		IF (packetsize < 0) OR (packetsize > MaxTCPPacketLength) THEN
			IF Trace THEN KernelLog.String('OSCTCPAgent: Packet too big: '); KernelLog.Hex(packetsize, 10); KernelLog.Ln; END;
			RETURN PacketTooBig;
		END;
		NEW(buffer, packetsize);
		client.Receive(buffer^, 0, packetsize, packetsize, len, res);
		IF res # TCP.Ok THEN RETURN res; END;
		ASSERT(len = packetsize);
		p := OSC.ParseOSCPacket(buffer^, packetsize);
		IF p = NIL THEN RETURN ParseError; END;
		RETURN Ok;
	END ReceiveTCP;

	PROCEDURE SendUDP(s: UDP.Socket; fip: IP.Adr; fport: LONGINT; p: OSC.OSCPacket): LONGINT;
	VAR
		buffer: OSC.String;
		res: WORD;
	BEGIN
		ASSERT(p # NIL);
		buffer := p.GetBytes();
		ASSERT(buffer # NIL);
		s.Send(fip, fport, buffer^, 0, LEN(buffer^), res);
		IF Trace THEN KernelLog.String('SendUDP: buffer: '); KernelLog.Buffer(buffer^, 0, LEN(buffer^)); KernelLog.String( ' fip '); IP.OutAdr(fip);
			KernelLog.String(' fport: '); KernelLog.Int(fport, 10); KernelLog.Ln; END;
		RETURN res;
	END SendUDP;
	(*
	PROCEDURE RecieveUDP(s: UDP.Socket; timeout (* in ms *): LONGINT;
								VAR fip: IP.Adr; VAR fport: LONGINT; VAR p: OSC.OSCPacket): LONGINT;
		VAR
			fip2: IP.Adr; fport2: LONGINT;
			size: LONGINT;
			buffer: Strings.String;
			got, res: LONGINT;
		BEGIN
			NEW(buffer, MaxUDPPacketLength);
			ASSERT(buffer # NIL);
			(* if fip = NILAdr, fport = 0 then recive from all, otherwise only from this port *)
			REPEAT
				s.Receive(buffer^, 0, MaxUDPPacketLength, timeout, gotfip, gotfport, res);
			UNTIL res # Ok

			(* Should we only receive from fip - if fip # NILAdr !!!! ???? *)
			s.Receive(buffer^, 0, MaxUDPPacketLength, timeout, fip2, fport2, got, res);
			IF res # UDP.Ok THEN RETURN res; END;
			size := got;
			(* parse packet *)
			p := OSC.ParseOSCPacket(buffer^, size);
			IF p = NIL THEN RETURN ParseError; END;
			RETURN Ok;
		END Recieve;
*)


	(* Testprocedures *)

	PROCEDURE TestUDPSend*;
		VAR
			socket: OSCUDPClient;
			p, p2: OSC.OSCMessage;
			attri: OSC.OSCParamInteger;
			attrs: OSC.OSCParamString;
			b: OSC.OSCBundle;
			tt: OSC.OSCTimeTag;
			ip: IP.Adr;
			res: WORD;
	BEGIN
		ip := IP.StrToAdr('192.168.150.1'); KernelLog.Int(res, 4);
		NEW(socket, ip, 57110, 57110, res); KernelLog.Int(res, 4);
		NEW(p, Strings.NewString('/abc/def/ghi'));
		NEW(attri, 01234H); p.AddArgument(attri);
		res := socket.Send(p);
		KernelLog.Int(res, 4); KernelLog.Ln;
		NEW(p2, Strings.NewString('/xyz'));
		NEW(attrs, Strings.NewString('<== This is a stirng in a Message ==>'));
		p2.AddArgument(attrs);
		NEW(tt); tt.SetLow(2005,12,26,18,12,15,999);
		NEW(b, tt, NIL, 0); b.AddPacket(p); b.AddPacket(p2);
		res := socket.Send(b);
		socket.Close;
		KernelLog.String('TestUDPSend done'); KernelLog.Ln;
	END TestUDPSend;

	PROCEDURE TestTCPSend*;
		VAR
			c: OSCTCPClient;
			p, p2: OSC.OSCMessage;
			attri: OSC.OSCParamInteger;
			attrs: OSC.OSCParamString;
			b: OSC.OSCBundle;
			tt: OSC.OSCTimeTag;
			ip: IP.Adr;
			res: WORD;
	BEGIN
		ip := IP.StrToAdr('192.168.150.1'); KernelLog.Int(res, 4);
		NEW(c, ip, 2009, TCP.NilPort, res); KernelLog.Int(res, 4);
		NEW(p, Strings.NewString('/abc/def/ghi'));
		NEW(attri, 01234H); p.AddArgument(attri);
		res := c.Send(p);
		KernelLog.Int(res, 4); KernelLog.Ln;
		NEW(p2, Strings.NewString('/xyz'));
		NEW(attrs, Strings.NewString('<== This is a stirng in a Message ==>'));
		p2.AddArgument(attrs);
		NEW(tt); tt.SetLow(2005,12,26,18,12,15,999);
		NEW(b, tt, NIL, 0); b.AddPacket(p); b.AddPacket(p2);
		res := c.Send(b);
		KernelLog.String('TestTCPSend done'); KernelLog.Ln;
		c.Close;
	END TestTCPSend;

END OSCNet.

OSCNet.TestUDPSend ~
OSCNet.TestTCPSend ~
OSCNet.TestUDPReceive ~
*)