MODULE OSCEval;

IMPORT OSC, OSCNet, OSCService, OSCRegistry, IP, UDP, TCP, KernelLog, Strings, TCPServices,
Network;

CONST

	ServerIP = "129.132.134.164";
	ServerPort = 1234;

VAR
	registry: OSCRegistry.OSCRegistry;
	sampleservice: OSCService.OSCService;
	udps: OSCNet.OSCUDPServer;
	tcps: OSCNet.OSCTCPServer;

	ackmessage: OSC.OSCMessage;
	nackmessage: OSC.OSCMessage;
	udpclient: OSCNet.OSCUDPClient;
	tcpclient: OSCNet.OSCTCPClient;

TYPE
	udpread = OBJECT
		VAR
			stopping: BOOLEAN;
			s: UDP.Socket;
			buffer: POINTER TO ARRAY OF CHAR;
			receivefip: IP.Adr;
			receivefport: LONGINT;
			got: SIZE;
			res: WORD;
			fip: IP.Adr;
		PROCEDURE &Init*;
		VAR
			res: WORD;
		BEGIN
			stopping := FALSE;
			NEW(buffer, 10000H);
			NEW(s, ServerPort, res);
			IF(res # UDP.Ok) THEN stopping := TRUE; END;
			fip := IP.StrToAdr(ServerIP);
		END Init;
		PROCEDURE Stop;
		BEGIN
			stopping := TRUE;
		END Stop;

	BEGIN {ACTIVE}
		WHILE ~ stopping DO
			s.Receive(buffer^, 0, LEN(buffer), 1000, receivefip, receivefport, got, res);
			IF res = UDP.Ok THEN
				s.Send(fip, receivefport, buffer^, 0, 8, res);
			END;
		END;
		s.Close;
	END udpread;

	tcpagent = OBJECT(TCPServices.Agent);
		VAR
			newpacket: OSC.OSCPacket;
			res: WORD;
			len: SIZE;
			buffer: POINTER TO ARRAY OF CHAR;
			sizebuf: ARRAY 4 OF CHAR;
			packetsize: LONGINT;

		PROCEDURE &StartOSCAgent*(c: TCP.Connection; s: TCPServices.Service);
		BEGIN
			Start(c,s);
		END StartOSCAgent;

	BEGIN { ACTIVE }
		client.Receive(sizebuf, 0, LEN(sizebuf), 4, len, res);
		IF res # TCP.Ok THEN Terminate; RETURN; END;
		ASSERT(len = 4);
		packetsize := Network.GetNet4(sizebuf, 0);
		(* allocate new buffer *)
		IF (packetsize < 0) OR (packetsize > 10000H) THEN
			KernelLog.String('OSCTCPAgent: Packet too big: '); KernelLog.Hex(packetsize, 10); KernelLog.Ln;
			Terminate; RETURN;
		END;
		NEW(buffer, packetsize);
		client.Receive(buffer^, 0, packetsize, packetsize, len, res);
		IF res # TCP.Ok THEN Terminate; RETURN; END;
		client.Send(buffer^, 0, 8, FALSE, res);
		Terminate;
	END tcpagent;

	tcpread = OBJECT
		VAR
			tcpservice: TCPServices.Service;

		(* starts the server: registers the OSCService s and creates the TCPServices.Service, which listens for connections *)
		PROCEDURE &InitTCPServer*;
		VAR
			res: WORD;
		BEGIN
			NEW(tcpservice, ServerPort, newAgent, res);
		END InitTCPServer;

		(* This function is called by tcpservice to create a new agent *)
		PROCEDURE newAgent(c: TCP.Connection; s: TCPServices.Service): TCPServices.Agent;
			VAR agent: tcpagent;
		BEGIN
			NEW(agent, c, s);
			RETURN agent;
		END newAgent;

		(* Stops the OSCTCPServer. Closes the listening socket and all established connections *)
		PROCEDURE Stop;
		BEGIN
			tcpservice.Stop;
		END Stop;

	END tcpread;


VAR
		udpr: udpread;
		tcpr: tcpread;


PROCEDURE StartUDPRead*;
BEGIN
	NEW(udpr);
END StartUDPRead;

PROCEDURE StopUDPRead*;
BEGIN
	IF udpr # NIL THEN udpr.Stop; udpr := NIL; END;
END StopUDPRead;

PROCEDURE StartTCPRead*;
BEGIN
	NEW(tcpr);
END StartTCPRead;

PROCEDURE StopTCPRead*;
BEGIN
	IF udpr # NIL THEN tcpr.Stop; tcpr := NIL; END;
END StopTCPRead;

PROCEDURE MessageTest1(m: OSC.OSCMessage);
VAR
	res: WORD;
BEGIN
	(* This Test should receive an empty OSC message *)
	IF (m.argumentcount = 0) & (~ m.noTypeTagString) THEN
		KernelLog.String('MessageTest1: success'); KernelLog.Ln;
		res := m.Return(ackmessage);
		RETURN;
	END;
	res := m.Return(nackmessage);
	KernelLog.String('MessageTest1: failed'); KernelLog.Ln;
END MessageTest1;

PROCEDURE SendMsg1*;
VAR
	m: OSC.OSCMessage;
	res: WORD;
BEGIN
	NEW(m, Strings.NewString('/tests/M1'));
	IF udpclient # NIL THEN res := udpclient.Send(m); END;
	IF tcpclient # NIL THEN res := tcpclient.Send(m); END;
	KernelLog.String('Sent message1'); KernelLog.Ln;
END SendMsg1;

PROCEDURE MessageTest2(m: OSC.OSCMessage);
VAR
	res: WORD;
	param: OSC.OSCParamObject;
BEGIN
	(* This Test should receive an OSC message with one Integer (47) *)
	IF (m.argumentcount = 1) & (~ m.noTypeTagString) THEN
		IF m.arguments[0] IS OSC.OSCParamInteger THEN
			param := m.arguments[0];
			WITH param: OSC.OSCParamInteger DO
				IF param.integer = 47 THEN
					KernelLog.String('MessageTest2: success'); KernelLog.Ln;
					res := m.Return(ackmessage);
					RETURN;
				END;
			END;
		END;
	END;
	res := m.Return(nackmessage);
	KernelLog.String('MessageTest2: failed'); KernelLog.Ln;
END MessageTest2;

PROCEDURE SendMsg2*;
VAR
	m: OSC.OSCMessage;
	i: OSC.OSCParamInteger;
	res: WORD;
BEGIN
	NEW(m, Strings.NewString('/tests/M2'));
	NEW(i, 47); m.AddArgument(i);
	IF udpclient # NIL THEN res := udpclient.Send(m); END;
	IF tcpclient # NIL THEN res := tcpclient.Send(m); END;
	KernelLog.String('Sent message2'); KernelLog.Ln;
END SendMsg2;

PROCEDURE MessageTest3(m: OSC.OSCMessage);
VAR
	res: WORD;
	param: OSC.OSCParamObject;
BEGIN
	(* This Test should receive an OSC message with one Float (8.25) *)
	IF (m.argumentcount = 1) & (~ m.noTypeTagString) THEN
		IF m.arguments[0] IS OSC.OSCParamFloat THEN
			param := m.arguments[0];
			WITH param: OSC.OSCParamFloat DO
				IF param.float = 8.25 THEN
					KernelLog.String('MessageTest3: success'); KernelLog.Ln;
					res := m.Return(ackmessage);
					RETURN;
				END;
			END;
		END;
	END;
	res := m.Return(nackmessage);
	KernelLog.String('MessageTest3: failed'); KernelLog.Ln;
END MessageTest3;

PROCEDURE SendMsg3*;
VAR
	m: OSC.OSCMessage;
	p: OSC.OSCParamFloat;
	res: WORD;
BEGIN
	NEW(m, Strings.NewString('/tests/M3'));
	NEW(p, 8.25); m.AddArgument(p);
	IF udpclient # NIL THEN res := udpclient.Send(m); END;
	IF tcpclient # NIL THEN res := tcpclient.Send(m); END;
	KernelLog.String('Sent message3'); KernelLog.Ln;
END SendMsg3;

PROCEDURE MessageTest4(m: OSC.OSCMessage);
VAR
	res: WORD;
	param: OSC.OSCParamObject;
	ok: BOOLEAN; i: LONGINT;
BEGIN
	(* This Test should receive an OSC message with one Blob (01 02 03 ... 20) *)
	IF (m.argumentcount = 1) & (~ m.noTypeTagString) THEN
		IF m.arguments[0] IS OSC.OSCParamBlob THEN
			param := m.arguments[0];
			WITH param: OSC.OSCParamBlob DO
				IF param.size = 32 THEN
					ok := TRUE;
					FOR i:=0 TO 31 DO
						IF param.blob[i] # CHR(i+1) THEN ok := FALSE; END;
					END;
					IF ok THEN
						KernelLog.String('MessageTest4: success'); KernelLog.Ln;
						res := m.Return(ackmessage);
						RETURN;
					END;
				END;
			END;
		END;
	END;
	res := m.Return(nackmessage);
	KernelLog.String('MessageTest5: failed'); KernelLog.Ln;
END MessageTest4;

PROCEDURE SendMsg4*;
VAR
	m: OSC.OSCMessage;
	p: OSC.OSCParamBlob;
	data: OSC.Blob; i: LONGINT;
	res: WORD;
BEGIN
	NEW(data, 32);
	FOR i:=0 TO 31 DO data[i] := CHR(i+1); END;
	NEW(m, Strings.NewString('/tests/M4'));
	NEW(p, data, 32); m.AddArgument(p);
	IF udpclient # NIL THEN res := udpclient.Send(m); END;
	IF tcpclient # NIL THEN res := tcpclient.Send(m); END;
	KernelLog.String('Sent message4'); KernelLog.Ln;
END SendMsg4;


PROCEDURE MessageTest5(m: OSC.OSCMessage);
VAR
	res: WORD;
	param: OSC.OSCParamObject;
BEGIN
	(* This Test should receive an OSC message with one String (TEST5)^5 *)
	IF (m.argumentcount = 1) & (~ m.noTypeTagString) THEN
		IF m.arguments[0] IS OSC.OSCParamString THEN
			param := m.arguments[0];
			WITH param: OSC.OSCParamString DO
				IF param.string^ = 'TEST5TEST5TEST5TEST5TEST5' THEN
					KernelLog.String('MessageTest5: success'); KernelLog.Ln;
					res := m.Return(ackmessage);
					RETURN;
				END;
			END;
		END;
	END;
	res := m.Return(nackmessage);
	KernelLog.String('MessageTest5: failed'); KernelLog.Ln;
END MessageTest5;

PROCEDURE SendMsg5*;
VAR
	m: OSC.OSCMessage;
	p: OSC.OSCParamString;
	res: WORD;
BEGIN
	NEW(m, Strings.NewString('/tests/M5'));
	NEW(p, Strings.NewString('TEST5TEST5TEST5TEST5TEST5')); m.AddArgument(p);
	m.dump(0); KernelLog.Ln;
	IF udpclient # NIL THEN res := udpclient.Send(m); END;
	IF tcpclient # NIL THEN res := tcpclient.Send(m); END;
	KernelLog.String('Sent message5'); KernelLog.Ln;
END SendMsg5;

PROCEDURE SendBundle1*;
VAR
	b: OSC.OSCBundle;
	tt: OSC.OSCTimeTag;
	res: WORD;
BEGIN
	NEW(tt); tt.SetImmediately;
	NEW(b, tt, NIL, 0);
	IF udpclient # NIL THEN res := udpclient.Send(b); END;
	IF tcpclient # NIL THEN res := tcpclient.Send(b); END;
	KernelLog.String('Sent bundle1'); KernelLog.Ln;
END SendBundle1;

PROCEDURE SendBundle2*;
VAR
	m: OSC.OSCMessage;
	b: OSC.OSCBundle;
	tt: OSC.OSCTimeTag;
	i: OSC.OSCParamInteger;
	res: WORD;
BEGIN
	NEW(tt); tt.SetImmediately;
	NEW(m, Strings.NewString('/tests/M2'));
	NEW(i, 47); m.AddArgument(i);
	NEW(b, tt, NIL, 0); b.AddPacket(m);
	IF udpclient # NIL THEN res := udpclient.Send(b); END;
	IF tcpclient # NIL THEN res := tcpclient.Send(b); END;
	KernelLog.String('Sent bundle2'); KernelLog.Ln;
END SendBundle2;

PROCEDURE SendBundle3*;
VAR
	m: OSC.OSCMessage;
	b: OSC.OSCBundle;
	tt: OSC.OSCTimeTag;
	i: OSC.OSCParamInteger;
	res: WORD;
BEGIN
	NEW(tt); tt.SetImmediately;
	NEW(m, Strings.NewString('/tests/M2'));
	NEW(i, 47); m.AddArgument(i);
	NEW(b, tt, NIL, 0);
	FOR res:=0 TO 49 DO
		 b.AddPacket(m);
	END;
	IF udpclient # NIL THEN res := udpclient.Send(b); END;
	IF tcpclient # NIL THEN res := tcpclient.Send(b); END;
	KernelLog.String('Sent bundle3'); KernelLog.Ln;
END SendBundle3;

PROCEDURE Echo(m: OSC.OSCMessage);
VAR
	res: WORD;
BEGIN
	IF ~ m.noTypeTagString THEN
		res := m.Return(ackmessage);
	ELSE
		res := m.Return(nackmessage);
	END;
END Echo;

PROCEDURE Ret(m: OSC.OSCMessage);
VAR
	res: WORD;
BEGIN
	IF ~ m.noTypeTagString THEN
		res := m.Return(m);
	ELSE
		res := m.Return(nackmessage);
	END;
END Ret;


PROCEDURE StartEvalService*;
VAR
	res: WORD;
BEGIN
	NEW(registry);
	registry.AddMethod(Strings.NewString('/tests/M1'), MessageTest1);
	registry.AddMethod(Strings.NewString('/tests/M2'), MessageTest2);
	registry.AddMethod(Strings.NewString('/tests/M3'), MessageTest3);
	registry.AddMethod(Strings.NewString('/tests/M4'), MessageTest4);
	registry.AddMethod(Strings.NewString('/tests/M5'), MessageTest5);
	registry.AddMethod(Strings.NewString('/echo'), Echo);
	registry.AddMethod(Strings.NewString('/ret'), Ret);
	NEW(sampleservice, registry);
	NEW(tcps, sampleservice, ServerPort, res);
	NEW(udps, sampleservice, ServerPort, res);
END StartEvalService;

PROCEDURE StopEvalService*;
BEGIN
	KernelLog.String('Stopping OSCTCP ');
	tcps.Stop;
	KernelLog.String('Stopping OSCUDP ');
	udps.Stop;
	KernelLog.String('Stopping OSCService ');
	sampleservice.Stop;
	KernelLog.String(' done'); KernelLog.Ln;
END StopEvalService;

PROCEDURE StartUDPClient*;
VAR
	res: WORD;
BEGIN
	NEW(udpclient, IP.StrToAdr(ServerIP), ServerPort, UDP.NilPort, res);
	IF res # UDP.Ok THEN
		KernelLog.String('creation failed'); KernelLog.Ln;
		udpclient := NIL;
		RETURN
	END;
	KernelLog.String('Started UDP client'); KernelLog.Ln;
END StartUDPClient;

PROCEDURE StopUDPClient*;
BEGIN
	IF udpclient # NIL THEN
		udpclient.Close;
		udpclient := NIL;
		KernelLog.String('Stopped UDP client'); KernelLog.Ln;
	END;
END StopUDPClient;

PROCEDURE StartTCPClient*;
VAR
	res: WORD;
BEGIN
	NEW(tcpclient, IP.StrToAdr(ServerIP), ServerPort, TCP.NilPort, res);
	IF res # TCP.Ok THEN
		KernelLog.String('creation failed'); KernelLog.Ln;
		udpclient := NIL;
		RETURN
	END;
	KernelLog.String('Started TCP client'); KernelLog.Ln;
END StartTCPClient;

PROCEDURE StopTCPClient*;
BEGIN
	IF tcpclient # NIL THEN
		tcpclient.Close;
		tcpclient := NIL;
		KernelLog.String('Stopped TCP client'); KernelLog.Ln;
	END;
END StopTCPClient;

BEGIN
	NEW(ackmessage, Strings.NewString('/OK'));
	NEW(nackmessage, Strings.NewString('/NOK'));
END OSCEval.

PC.Compile OSCStrings.Mod OSC.Mod OSCRegistry.Mod OSCQueue.Mod OSCService.Mod OSCNet.Mod OSCEval.Mod ~
System.Free OSCEval OSCTest OSCNet OSCService OSCQueue OSCRegistry OSC OSCUtilities ~

OSCEval.StartEvalService ~
OSCEval.StopEvalService ~

OSCEval.StartUDPClient ~
OSCEval.StopUDPClient ~

OSCEval.StartTCPClient ~
OSCEval.StopTCPClient ~

OSCEval.SendMsg1 ~
OSCEval.SendMsg2 ~
OSCEval.SendMsg3 ~
OSCEval.SendMsg4 ~
OSCEval.SendMsg5 ~
OSCEval.SendBundle1 ~
OSCEval.SendBundle2 ~
OSCEval.SendBundle3 ~

OSCEval.StartUDPRead ~
OSCEval.StopUDPRead ~

OSCEval.StartTCPRead ~
OSCEval.StopTCPRead ~
