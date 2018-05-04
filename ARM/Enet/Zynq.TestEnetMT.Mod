MODULE Test;

IMPORT
	SYSTEM, Trace := EnetTrace, Platform, Kernel, Machine, EnetTiming, EnetBase, Enet, EmacPs7 := EnetEmacPs7, Objects, EnetArp, EnetIcmp, EnetUdp, Commands, EnetUtils, Interfaces := EnetInterfaces;

TYPE
	Int16 = EnetBase.Int16;
	Int32 = EnetBase.Int32;
	Int = EnetBase.Int;

	UnalignedInt32 = EnetUtils.UnalignedInt32;

CONST
	IntfMacAddr = "00:0A:35:00:01:02";
	IntfIpAddr = "10.3.34.8";
	IntfGateway = "0.0.0.0";
	IntfSubnetMask = "255.255.255.0";
	LocalUdpPort = 65534;

VAR
	intf: Enet.Interface;
	udpSocket: EnetUdp.Socket;

	recvCounter: Int;

	data: ARRAY 1470 OF CHAR;

	lockIntfs: BOOLEAN;

	PROCEDURE Start*;
	VAR res: Int;
	BEGIN
		recvCounter := 0;
		ASSERT(Interfaces.Start(intf,res));
	END Start;

	PROCEDURE Stop*;
	VAR res: Int;
	BEGIN
		ASSERT(Interfaces.Stop(intf,res));
	END Stop;

	PROCEDURE Reset*;
	VAR res: Int;
	BEGIN
		ASSERT(Interfaces.Reset(intf,res));
	END Reset;

	PROCEDURE ShowArpCache*;
	BEGIN
		EnetArp.ShowArpCache(intf.ipv4AddrCache(EnetArp.ArpCache));
	END ShowArpCache;

	PROCEDURE ShowRecvCounter*;
	BEGIN
		Trace.StringLn("recvCounter=" & recvCounter);
	END ShowRecvCounter;

	PROCEDURE SendPackets1*(context: Commands.Context);
	VAR
		i, n: LONGINT;
		ipAddr: EnetBase.IpAddr;
		res: Int;
		t: EnetTiming.Time;
	BEGIN
		ASSERT(context.arg.GetInteger(n,FALSE));

		FOR i := 0 TO LEN(data)-1 DO
			data[i] := CHR(i+1);
		END;

		Trace.StringLn("sending " & n & " UDP datagrams...");

		Trace.RefTimestamp(0);
		WHILE (n > 0) & EnetUdp.Send(udpSocket,data,0,LEN(data),{},NIL,res) DO
			DEC(n);
		END;
		Trace.Timestamp(0,"sending time: ");

		IF n = 0 THEN
			Trace.StringLn("all UDP datagrams have been sent");
		ELSE
			Trace.StringLn("a failure to send UDP datagram, res=" & res & ", number of remained datagrams to send is" & n);
		END;

	END SendPackets1;

	PROCEDURE SendPackets2*(context: Commands.Context);
	VAR
		i, n: LONGINT;
		ipAddr: EnetBase.IpAddr;
		res: Int;
		t: EnetTiming.Time;
	BEGIN
		ASSERT(context.arg.GetInteger(n,FALSE));

		FOR i := 0 TO LEN(data)-1 DO
			data[i] := CHR(i+1);
		END;

		Trace.StringLn("sending " & n & " UDP datagrams...");

		Trace.RefTimestamp(0);
		WHILE (n > 0) & EnetUdp.Send(udpSocket,data,0,LEN(data),{EnetBase.FlagNoDataCopy},NIL,res) DO
			DEC(n);
		END;
		Trace.Timestamp(0,"sending time: ");

		IF n = 0 THEN
			Trace.StringLn("all UDP datagrams have been sent");
		ELSE
			Trace.StringLn("a failure to send UDP datagram, res=" & res & ", number of remained datagrams to send is" & n);
		END;

	END SendPackets2;

	PROCEDURE SendPackets3*(context: Commands.Context);
	VAR
		i, n: LONGINT;
		ipAddr: EnetBase.IpAddr;
		res: Int;
		t: EnetTiming.Time;
	BEGIN
		ASSERT(context.arg.GetInteger(n,FALSE));

		FOR i := 0 TO LEN(data)-1 DO
			data[i] := CHR(i+1);
		END;

		Trace.StringLn("sending " & n & " UDP datagrams...");

		Trace.RefTimestamp(0);
		WHILE (n > 0) & EnetUdp.Send(udpSocket,data,0,LEN(data),{EnetBase.FlagNoDataCopy,EnetBase.FlagNoFlushDCache},NIL,res) DO
			DEC(n);
		END;
		Trace.Timestamp(0,"sending time: ");

		IF n = 0 THEN
			Trace.StringLn("all UDP datagrams have been sent");
		ELSE
			Trace.StringLn("a failure to send UDP datagram, res=" & res & ", number of remained datagrams to send is" & n);
		END;

	END SendPackets3;

VAR
	setUdpDestTaskCompleted: BOOLEAN;

	PROCEDURE SetUdpDestTaskHandler(completionHandler: EnetBase.TaskHandler);
	BEGIN{EXCLUSIVE}
		setUdpDestTaskCompleted := TRUE;
	END SetUdpDestTaskHandler;

	(**
		Setup UDP socket destination

		Syntax:

		SetUdpDest dstIpAddr dstPort ~
	*)
	PROCEDURE SetUdpDest*(context: Commands.Context);
	VAR
		strDstIpAddr: ARRAY 16 OF CHAR;
		dstPort: Int;
		dstIpAddr: EnetBase.IpAddr;
		completionHandler: EnetBase.TaskHandler;
		res: Int;
	BEGIN
		IF ~context.arg.GetString(strDstIpAddr) OR ~context.arg.GetInteger(dstPort,FALSE) THEN
			context.result := 1;
			context.error.String("destination IP address and destination port number are expected!"); context.error.Ln;
			RETURN;
		END;
		IF ~EnetBase.StrToIpAddr(strDstIpAddr,dstIpAddr) THEN
			context.result := 1;
			context.error.String("destination IP address string has invalid format!"); context.error.Ln;
			RETURN;
		END;

		NEW(completionHandler);
		completionHandler.handle := SetUdpDestTaskHandler;
		setUdpDestTaskCompleted := FALSE;
		IF ~EnetUdp.SetDestination(udpSocket,dstIpAddr,dstPort,completionHandler,res) THEN
			context.result := res;
			context.error.String("failed to setup image streaming destination!"); context.error.Ln;
			RETURN;
		END;

		IF res = EnetBase.OpInProgress THEN

			BEGIN{EXCLUSIVE}
				AWAIT(setUdpDestTaskCompleted);
			END;
			IF completionHandler.res # 0 THEN
				context.result := completionHandler.res;
				context.error.String("failed to setup image streaming destination!"); context.error.Ln;
				RETURN;
			END;
		ELSIF res # 0 THEN
			context.result := res;
			context.error.String("failed to setup image streaming destination!"); context.error.Ln;
		END;

		context.result := 0;
		context.out.String("Ok"); context.out.Ln;
	END SetUdpDest;


	PROCEDURE Test*;
	VAR
		t: EnetTiming.Time;
		x16, y16: Int16;
		x32, y32: Int32;
		u32: EnetUtils.UnalignedInt32;
	BEGIN

		x16 := Int16(0x1234);
		t := EnetTiming.getTimeCounter();
		y16 := EnetUtils.SwitchEndianness16(x16);
		t := EnetTiming.getTimeCounter() - t;
		Trace.StringLn("SwitchEndianness16: " & t);
		Trace.StringLn("y16=0x" & Trace.Hx(y16,4));

		x32 := Int32(0x12345678);
		t := EnetTiming.getTimeCounter();
		y32 := EnetUtils.SwitchEndianness32(x32);
		t := EnetTiming.getTimeCounter() - t;
		Trace.StringLn("SwitchEndianness32: " & t);
		Trace.StringLn("y32=0x" & Trace.Hx(y32,8));

		t := EnetTiming.getTimeCounter();
		u32 := x32;
		t := EnetTiming.getTimeCounter() - t;
		Trace.StringLn("u32 := x32: " & t);
		Trace.StringLn("u32=0x" & Trace.Hx(u32[3],2) & Trace.Hx(u32[2],2) & Trace.Hx(u32[1],2) & Trace.Hx(u32[0],2));

		x32 := 0;

		t := EnetTiming.getTimeCounter();
		x32 := u32;
		t := EnetTiming.getTimeCounter() - t;
		Trace.StringLn("x32 := u32: " & t);
		Trace.StringLn("x32=0x" & Trace.Hx(x32,8));
	END Test;

	PROCEDURE Print *;
	VAR
		str: ARRAY 128 OF CHAR;
	BEGIN
		IF EnetBase.IpAddrToStr(intf.ipv4Addr, str) THEN
			Trace.StringLn(str)
		ELSE
			Trace.StringLn("ERROR: could not translate IP address")
		END
	END Print;

	PROCEDURE UdpRecvHandler(
											socket: EnetUdp.Socket;
											CONST srcAddr: EnetBase.IpAddr;
											srcPort: EnetBase.Int;
											VAR data: ARRAY OF CHAR;
											dataOffs, dataLen: EnetBase.Int;
											packet: EnetBase.Packet
											);
	VAR res: Int;
	BEGIN
		INC(recvCounter);
		(*
		socket.sendToIpAddr := srcAddr;
		socket.sendToPort := srcPort;
		socket.sendToMacAddr := packet.ethFrameHdr.srcMacAddr;
		socket.intf := packet.intf;
		IF ~EnetUdp.Send(socket,data,dataOffs,dataLen,{},opRes) THEN
			Trace.StringLn("failed to send a UDP datagram, res=" & opRes.res);
		END;
		*)
(*
		IF ~EnetBase.ReplyUdp(packet.intf,packet,{},NIL,res) THEN
			Trace.StringLn("failed to reply to a UDP datagram, res=" & res);
		END;
*)

(*
		Trace.StringLn("received a datagram, srcIpAddr=0x" & Trace.Hx(srcAddr.addr[0],8) & ", srcPort=0x" & Trace.Hx(srcPort,4) & ", dataLen=" & dataLen);
		WHILE dataLen > 0 DO
			Trace.String(Trace.Hx(ORD(data[dataOffs]),2) & " ");
			i := (i+1) MOD 8;
			IF i = 0 THEN Trace.StringLn(""); END;
			INC(dataOffs);
			DEC(dataLen);
		END;
		Trace.StringLn("");
	(*
		runner.socket.sendToIpAddr.addr[0] := packet.ipv4Hdr.srcIpAddr;
		runner.socket.sendToIpAddr.isIpv4 := TRUE;
		runner.socket.sendToMacAddr := packet.ethFrameHdr.srcMacAddr;
		runner.socket.sendToPort := EnetBase.SwitchEndianness16(packet.udpHdr.srcPort);
	*)
*)
	END UdpRecvHandler;

	PROCEDURE InitMod;
	VAR
		res: LONGINT;
		dev: EnetBase.LinkDevice;
		macAddr: EnetBase.MacAddr;
		ipAddr, gateway, subnetMask: EnetBase.IpAddr;
	BEGIN

		(* initialize the interface *)
		ASSERT(EmacPs7.GetDevice(0,2048,2048,8192,8192,dev,res));
		NEW(intf,dev,res); ASSERT(res = 0);

		(* setup link layer of the interface *)
		ASSERT(EnetBase.StrToMacAddr(IntfMacAddr,macAddr));
		ASSERT(Interfaces.SetMacAddr(intf,macAddr,res));
		ASSERT(Interfaces.SetLinkSpeed(intf,"Auto",TRUE,res));

		(* setup IP configuration of the interface *)
		ASSERT(EnetBase.StrToIpAddr(IntfIpAddr,ipAddr));
		ASSERT(EnetBase.StrToIpAddr(IntfSubnetMask,subnetMask));
		ASSERT(EnetBase.StrToIpAddr(IntfGateway,gateway));
		ASSERT(Interfaces.SetIpConfig(intf,ipAddr,subnetMask,gateway,res));

		ASSERT(Interfaces.Add(intf,res));

		(* create a UDP socket *)
		ASSERT(EnetUdp.NewSocket(udpSocket,LocalUdpPort,res));
		ASSERT(EnetUdp.SetRecvHandler(udpSocket,UdpRecvHandler,res));
	END InitMod;

BEGIN
	InitMod;
END Test.

(* KRM *)
FSTools.CreateFile -c -r Replacements.tmp
BootConfig.UartInputClockHz = 100000000;
BootConfig.KernelOutputUart = 0;
BootConfig.CpuNb = 2;
EnetBase.ThreadSafe = TRUE;
Enet.UseSpinLocks = TRUE;
~

(* ZYBO & ZedBoard *)
FSTools.CreateFile -c -r Replacements.tmp
BootConfig.UartInputClockHz = 50000000;
BootConfig.KernelOutputUart = 1;
BootConfig.CpuNb = 1;
EnetBase.ThreadSafe = TRUE;
Enet.UseSpinLocks = TRUE;
EnetEmacPs7.AllowZeroPhyAddr = [TRUE,TRUE];
~

SystemTools.DoCommands
FSTools.Unsafe ~
FSTools.DeleteFiles "*.Gof" "*.Sym" ~
FSTools.Safe ~
~

SystemTools.DoCommands
Release.Build -b -f=ARM.Release.Tool -o='--replacements=Replacements.tmp --noInitLocals --traceModule=Trace' --only="Kernel" ZynqA2 ~
Release.Build -b -f=ARM.Release.Tool -o='--replacements=Replacements.tmp --traceModule=Trace' --only="System Enet Shell" ZynqA2 ~
Compiler.Compile -b=ARM --traceModule=Trace --objectFile=Generic --newObjectFile --replacements=Replacements.tmp
	ENET:Zynq.TestEnetMT.Mod
~
~

Release.Build -l -f=ARM.Release.Tool --only="Kernel System Enet Shell" ZynqA2 ~

FSTools.CloseFiles Test.bin ~

FoxARMInstructionSet.Disassemble Test.bin -a=19cc8cH  ~
