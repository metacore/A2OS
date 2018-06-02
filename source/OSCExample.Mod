(* Copyright 2005-2006, Markus Heule, ETH Zurich *)

MODULE OSCExample;  (** AUTHOR "heulemar"; PURPOSE "OpenSoundControl: sampleprogram"; *)

(*
	This module contains a sample oscservice to illustrate the usage of the OSC framework.

	1.) (if needed) Compile the whole framework:

	PC.Compile OSCStrings.Mod OSC.Mod OSCRegistry.Mod OSCQueue.Mod OSCService.Mod OSCNet.Mod OSCExample.Mod ~

	2.) Start the service with:

	OSCExample.StartSampleService ~

	3.) Stop the sample service with:

	OSCExample.StopSampleService ~

	4.) (if needed) Unload the modules from the framework.

	SystemTools.Free OSCExample OSCNet OSCService OSCQueue OSCRegistry OSC OSCUtilities ~

*)

IMPORT OSC, OSCNet, OSCService, OSCRegistry, IP, UDP, KernelLog, Strings;

VAR
	registry: OSCRegistry.OSCRegistry;
	sampleservice: OSCService.OSCService;
	udps: OSCNet.OSCUDPServer;
	tcps: OSCNet.OSCTCPServer;


(* client procedure, which sends the received packet back to the sender *)
PROCEDURE EchoPacket(p: OSC.OSCMessage);
VAR
	res: WORD;
BEGIN
	res := p.Return(p);
END EchoPacket;

(* client procedure, which dumps the received packet *)
PROCEDURE DumpPacket(p: OSC.OSCMessage);
VAR
	i: LONGINT;
	param: OSC.OSCParamObject;
BEGIN
	KernelLog.String('Dumping whole packet: '); KernelLog.Ln;
	p.dump(1);
	(* this shows how to access parameters *)
	KernelLog.String('Dumping each parameter separatly:'); KernelLog.Ln;
	FOR i:=0 TO p.argumentcount -1 DO
		param := p.arguments[i];
		IF param IS OSC.OSCParamInteger THEN
			WITH param: OSC.OSCParamInteger DO
				KernelLog.String('Int: '); KernelLog.Int(param.integer, 10);
				KernelLog.String('('); KernelLog.Hex(param.integer, 1); KernelLog.String(')'); KernelLog.Ln;
			END;
		END;
	END;
	KernelLog.String('Dumping packet done'); KernelLog.Ln;
END DumpPacket;

PROCEDURE StartSampleService*;
VAR
	res: WORD;
BEGIN
	NEW(registry);	(* creates a new registry *)
	registry.AddMethod(Strings.NewString('/dumpme'), DumpPacket); (* register a new procedure *)
	registry.AddMethod(Strings.NewString('/echome'), EchoPacket); (* register another one *)
	NEW(sampleservice, registry); (* creates a new oscservice *)
	NEW(tcps, sampleservice, 57110, res); (* listens on TCP port 57110 for connections from the network *)
	NEW(udps, sampleservice, 57110, res); (* listens on UDP port 57110 for packet from the network *)
END StartSampleService;

PROCEDURE StopSampleService*;
BEGIN
	KernelLog.String('Stopping OSCTCP ');
	tcps.Stop;
	KernelLog.String('Stopping OSCUDP ');
	udps.Stop;
	KernelLog.String('Stopping OSCService ');
	sampleservice.Stop;
	KernelLog.String(' done'); KernelLog.Ln;
END StopSampleService;

PROCEDURE SampleClient*;
VAR
	msg: OSC.OSCMessage;
	i: OSC.OSCParamInteger;
	f: OSC.OSCParamFloat;
	udp: OSCNet.OSCUDPClient;
	fip: IP.Adr;
	fport: LONGINT;
	res: WORD;
	b: OSC.OSCBundle;
	tt: OSC.OSCTimeTag;
BEGIN
	NEW(msg, Strings.NewString('/some/method'));
	NEW(i, 4);
	NEW(f, 8.25);
	msg.AddArgument(i);
	msg.AddArgument(f);
	NEW(tt); tt.Set(OSC.TTGetSecondsNow(), 0);
	NEW(b, tt, NIL, 0);
	fip := IP.StrToAdr('192.168.150.1');
	fport := 1234;
	NEW(udp, fip, fport, UDP.NilPort, res);
	IF res # UDP.Ok THEN
		KernelLog.String('SampleClient: Error creating UDP client');
		RETURN;
	END;
	KernelLog.String('SampleClient: Sending message now');
	res := udp.Send(msg);
	res := udp.Send(b);
	KernelLog.String(' done'); KernelLog.Ln;
	udp.Close;
END SampleClient;

END OSCExample.

PC.Compile OSCStrings.Mod OSC.Mod OSCRegistry.Mod OSCQueue.Mod OSCService.Mod OSCNet.Mod OSCExample.Mod ~
SystemTools.Free OSCExample OSCNet OSCService OSCQueue OSCRegistry OSC OSCUtilities ~

OSCExample.StartSampleService ~
OSCExample.StopSampleService ~

OSCExample.SampleClient ~