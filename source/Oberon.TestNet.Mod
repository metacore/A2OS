(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE TestNet IN Oberon; (** AUTHOR "pjm, mvt"; PURPOSE "Module for testing network device drivers"; *)

IMPORT Kernel IN A2, Modules IN A2, KernelLog IN A2, Plugins IN A2, Network IN A2, Texts, Oberon, In;

CONST
	TestSendType = 0DEADH;
	TestReplyType = 0BEEFH;

VAR
	w: Texts.Writer;
	dev, dev2: Network.LinkDevice;
	replies: SIGNED32;
	received: SIGNED32;
	peer: Network.LinkAdr;
	nofpkt: SIGNED32;
	startTime: SIGNED32;

(** Show all registered link devices. *)

PROCEDURE ShowDevices*;
VAR table: Plugins.Table; dev: Network.LinkDevice; i: SIGNED32; s: ARRAY 32 OF CHAR;
BEGIN
	Network.registry.GetAll(table);
	IF table # NIL THEN
		FOR i := 0 TO LEN(table)-1 DO
			dev := table[i](Network.LinkDevice);
			Texts.WriteString(w, dev.name);
			IF dev.type = Network.TypeEthernet THEN
				Texts.WriteString(w, " Ethernet ");
			ELSIF dev.type = Network.TypePointToPoint THEN
				Texts.WriteString(w, " Point-to-point ")
			ELSE
				Texts.WriteString(w, " Unknown ")
			END;
			Network.LinkAdrToStr(dev.local, dev.adrSize, s);
			Texts.WriteString(w, s); Texts.Write(w, " ");
			Network.LinkAdrToStr(dev.broadcast, dev.adrSize, s);
			Texts.WriteString(w, s); Texts.Write(w, " ");
			Texts.WriteInt(w, dev.mtu, 1); Texts.Write(w, " ");

			(* does not work with SIGNED64:
			Texts.WriteInt(w, dev.sendCount, 1); Texts.Write(w, " ");
			Texts.WriteInt(w, dev.recvCount, 1);
			*)

			Texts.WriteLn(w);
			Texts.Append(Oberon.Log, w.buf)
		END
	END
END ShowDevices;

PROCEDURE FindDevice(name: ARRAY OF CHAR): Network.LinkDevice;
VAR table: Plugins.Table; i: SIGNED32;
BEGIN
	Network.registry.GetAll(table);
	IF table # NIL THEN
		FOR i := 0 TO LEN(table)-1 DO
			IF table[i].name = name THEN RETURN table[i](Network.LinkDevice) END
		END
	END;
	RETURN NIL
END FindDevice;

PROCEDURE Receiver(dev: Network.LinkDevice; type: SIGNED32; buf: Network.Buffer);
(* VAR s: ARRAY 32 OF CHAR; *)
BEGIN
(*
	KernelLog.Enter; KernelLog.Hex(type, 9); KernelLog.Char(" ");
	Network.LinkAdrToStr(buf.src, dev.adrSize, s); KernelLog.String(s); KernelLog.Ln;
	KernelLog.Memory(ADDRESSOF(buf.data[buf.ofs]), buf.len);
	KernelLog.Exit;
*)
	IF type = TestSendType THEN
		IF ~ODD(ORD(buf.src[0])) THEN	(* reply to unicast sources *)
			INC(received);
			dev.Send(buf.src, TestReplyType, buf.data, buf.data, buf.data, 0, 0, buf.ofs, buf.len, FALSE)
		END
	ELSIF type = TestReplyType THEN
		INC(replies); peer := buf.src;
		IF replies >= nofpkt THEN
			KernelLog.String("Finished. ms="); KernelLog.Int(Kernel.GetTicks()-startTime, 0); KernelLog.Ln;
		END;
	END;
	Network.ReturnBuffer(buf);
END Receiver;

(** Set the test device. *)

PROCEDURE SetDevice*;	(** devname ~ *)
VAR name: ARRAY 32 OF CHAR;
BEGIN
	In.Open; In.String(name);
	IF In.Done THEN
		dev := FindDevice(name);
		IF dev # NIL THEN
			Texts.WriteString(w, name); Texts.WriteString(w, " is now the test device");
			Texts.WriteLn(w); Texts.Append(Oberon.Log, w.buf);
			dev.InstallReceiver(SELF, TestSendType, Receiver, IsPacketValid, IsPacketForSingleRec, IsPacketAccepted, FALSE);
			dev.InstallReceiver(SELF, TestReplyType, Receiver, IsPacketValid, IsPacketForSingleRec, IsPacketAccepted, FALSE);
		ELSE
			Texts.WriteString(w, name); Texts.WriteString(w, " not found");
			Texts.WriteLn(w); Texts.Append(Oberon.Log, w.buf)
		END
	END
END SetDevice;

(** Set the 2nd test device. *)

PROCEDURE SetDevice2*;	(** devname ~ *)
VAR name: ARRAY 32 OF CHAR;
BEGIN
	In.Open; In.String(name);
	IF In.Done THEN
		dev2 := FindDevice(name);
		IF dev2 # NIL THEN
			Texts.WriteString(w, name); Texts.WriteString(w, " is now the 2nd test device");
			Texts.WriteLn(w); Texts.Append(Oberon.Log, w.buf);
			dev.InstallReceiver(SELF, TestSendType, Receiver, IsPacketValid, IsPacketForSingleRec, IsPacketAccepted, FALSE);
			dev.InstallReceiver(SELF, TestReplyType, Receiver, IsPacketValid, IsPacketForSingleRec, IsPacketAccepted, FALSE);
		ELSE
			Texts.WriteString(w, name); Texts.WriteString(w, " not found");
			Texts.WriteLn(w); Texts.Append(Oberon.Log, w.buf)
		END
	END
END SetDevice2;

(** Broadcast a test packet. *)

PROCEDURE SendBroadcast*;
VAR i: SIGNED32; data: ARRAY 100 OF CHAR;
BEGIN
	IF dev # NIL THEN
		replies := 0;
		nofpkt := 1;
		startTime := Kernel.GetTicks();
		FOR i := 0 TO LEN(data)-1 DO data[i] := CHR(i MOD 100H) END;
		dev.Send(dev.broadcast, TestSendType, data, data, data, 0, 0, 0, LEN(data), FALSE)
	END
END SendBroadcast;

(** Send test packets to peer. *)

PROCEDURE SendTest*;	(* n ~ *)
VAR i, n: SIGNED32; data: ARRAY 1500 OF CHAR;
BEGIN
	In.Open; In.LongInt(n);
	IF (dev # NIL) & In.Done THEN
		replies := 0;
		nofpkt := n;
		startTime := Kernel.GetTicks();
		FOR i := 0 TO LEN(data)-1 DO data[i] := CHR(i MOD 100H) END;
		FOR i := 0 TO n-1 DO
			data[0] := CHR(i DIV 100H);
			data[1] := CHR(i MOD 100H);
			dev.Send(peer, TestSendType, data, data, data, 0, 0, 0, LEN(data), FALSE);
		END
	END
END SendTest;


(* Checks if an incoming packet should be sent to only one installed receivers *)
PROCEDURE IsPacketForSingleRec* (buffer: Network.Buffer): BOOLEAN;
BEGIN
	RETURN FALSE;
END IsPacketForSingleRec;


(* Checks if an incoming packet is accepted from a certain installed receiver *)
PROCEDURE IsPacketAccepted* (buffer: Network.Buffer): BOOLEAN;
BEGIN
	RETURN TRUE;
END IsPacketAccepted;


(* Checks if an incoming packet is valid *)
PROCEDURE IsPacketValid* (VAR buffer: Network.Buffer): BOOLEAN;
BEGIN
	RETURN TRUE;
END IsPacketValid;


PROCEDURE Cleanup;
BEGIN
	IF dev # NIL THEN
		dev.RemoveReceiver(SELF, TestSendType);
		dev.RemoveReceiver(SELF, TestReplyType);
	END;
	IF dev2 # NIL THEN
		dev2.RemoveReceiver(SELF, TestSendType);
		dev2.RemoveReceiver(SELF, TestReplyType);
	END;
END Cleanup;

BEGIN
	Texts.OpenWriter(w);
	dev := NIL;
	Modules.InstallTermHandler(Cleanup);
END TestNet.

(* History:
21.10.2003	mvt	Changed for new Network interface
21.11.2003	mvt	Added support for 2nd (reply) device
*)

TestNet.ShowDevices
TestNet.SetDevice "3Com90x#0"
TestNet.SetDevice2 "3Com90x#1"
TestNet.SendBroadcast  TestNet.SendTest ^ 1 10 100 1000 10000

System.Free TestNet~
