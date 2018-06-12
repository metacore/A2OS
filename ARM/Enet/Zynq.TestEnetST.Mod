MODULE Test;

IMPORT
	SYSTEM, Trace := EnetTrace, Platform, Kernel, EnetTiming, EnetBase, EmacPs7 := EnetEmacPs7, Objects, EnetArp, EnetIcmp, EnetUdp, Enet, Commands, Interfaces := EnetInterfaces;

CONST
	IntfMacAddr = "00:0A:35:00:01:02";
	IntfIpAddr = "10.3.34.8";
	IntfGateway = "0.0.0.0";
	IntfSubnetMask = "255.255.255.0";
	LocalUdpPort = 65534;

TYPE
	Int16 = EnetBase.Int16;
	Int32 = EnetBase.Int32;
	Int = EnetBase.Int;

	Runner = OBJECT
	VAR
		res: Int;
		completionHandler: EnetBase.TaskHandler;
		timer: Kernel.Timer;

		alive: BOOLEAN;
		exited: BOOLEAN;
		waiting, waitingReq: BOOLEAN;

		sendFlag, setUdpDestFlag: BOOLEAN;

		dstIpAddr: EnetBase.IpAddr;
		dstPort: Int;

		numPacketsToSend: Int;

		PROCEDURE &InitRunner();
		BEGIN

			alive := TRUE;
			waitingReq := TRUE;
			waiting := TRUE;
			exited := FALSE;

			sendFlag := FALSE;
			setUdpDestFlag := FALSE;

			NEW(timer);
			NEW(completionHandler);
		END InitRunner;

		PROCEDURE Start*(VAR res: Int): BOOLEAN;
		BEGIN
			ASSERT(alive);
			IF Interfaces.StartAll(res) THEN
				BEGIN{EXCLUSIVE}
					waitingReq := FALSE;
					waiting := FALSE;
				END;
				RETURN TRUE;
			ELSE
				RETURN FALSE;
			END;
		END Start;

		PROCEDURE Stop*(VAR res: Int): BOOLEAN;
		VAR b: BOOLEAN;
		BEGIN
			ASSERT(alive);

			BEGIN{EXCLUSIVE}
				waitingReq := TRUE;
				AWAIT(waiting);
			END;
			RETURN Interfaces.StopAll(res);
		END Stop;

		PROCEDURE Reset*(VAR res: Int): BOOLEAN;
		VAR b: BOOLEAN;
		BEGIN
			ASSERT(alive);

			BEGIN{EXCLUSIVE}
				waitingReq := TRUE;
				AWAIT(waiting);
			END;
			RETURN Interfaces.ResetAll(res);
		END Reset;

		PROCEDURE Finalize(VAR res: Int): BOOLEAN;
		VAR b: BOOLEAN;
		BEGIN
			b := Stop(res);
			alive := FALSE;
			BEGIN{EXCLUSIVE}
				AWAIT(exited);
			END;
			RETURN b;
		END Finalize;

		PROCEDURE TriggerSend;
		BEGIN{EXCLUSIVE}
			sendFlag := TRUE;
		END TriggerSend;

		PROCEDURE TriggerSetUdpDest;
		BEGIN{EXCLUSIVE}
			setUdpDestFlag := TRUE;
		END TriggerSetUdpDest;

		PROCEDURE UdpRecvHandler(
												udpSocket: EnetUdp.Socket;
												CONST srcAddr: EnetBase.IpAddr;
												srcPort: EnetBase.Int;
												VAR data: ARRAY OF CHAR;
												dataOffs, dataLen: EnetBase.Int;
												packet: EnetBase.Packet
												);
		BEGIN

		END UdpRecvHandler;

		PROCEDURE SendPackets(n: Int);
		VAR
			data: ARRAY 1470 OF CHAR;
			i: Int;
		BEGIN
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
				Trace.StringLn("a failure to send UDP datagram, number of remained datagrams to send is" & n);
			END;

		END SendPackets;

		PROCEDURE SetUdpDest;
		VAR res: Int;
		BEGIN
			IF ~EnetUdp.SetDestination(udpSocket,dstIpAddr,dstPort,completionHandler,res) THEN
				Trace.StringLn("failed to setup image streaming destination, res=" & res);
				RETURN;
			END;
			IF res = EnetBase.OpInProgress THEN
				ASSERT((completionHandler.res = EnetBase.OpInProgress));
				WHILE (completionHandler.res = EnetBase.OpInProgress) & Interfaces.UpdateAll(res) DO
				END;
				IF res # 0 THEN
					Trace.StringLn("interface update error, res=" & res);
					RETURN;
				END;
				res := completionHandler.res;
			END;

			IF res = 0 THEN
				Trace.StringLn("image streaming destination has been set up");
			ELSE
				Trace.StringLn("failed to setup image streaming destination, res=" & res);
			END;
		END SetUdpDest;

	BEGIN{ACTIVE,PRIORITY(Objects.Realtime)}

		WHILE alive DO
			IF ~waitingReq THEN

				IF Interfaces.UpdateAll(res) THEN

					IF sendFlag THEN
						sendFlag := FALSE;
						SendPackets(numPacketsToSend);
					ELSIF setUdpDestFlag THEN
						setUdpDestFlag := FALSE;
						SetUdpDest;
					END;

				ELSE
					BEGIN{EXCLUSIVE} waitingReq := TRUE; END;
				END;

			ELSE
				BEGIN{EXCLUSIVE}
					waiting := TRUE;
					AWAIT(~waiting OR ~alive)
				END;
			END;
		END;

		BEGIN{EXCLUSIVE}
			exited := TRUE;
		END;

	END Runner;

VAR
	runner: Runner;

	intf: Enet.Interface;
	udpSocket: EnetUdp.Socket;

	recvCounter: Int;

	PROCEDURE Start*(context: Commands.Context);
	BEGIN
		IF ~runner.Start(context.result) THEN
		END;
	END Start;

	PROCEDURE Stop*(context: Commands.Context);
	BEGIN
		IF ~runner.Stop(context.result) THEN
		END;
	END Stop;

	PROCEDURE Reset*(context: Commands.Context);
	BEGIN
		IF ~runner.Reset(context.result) THEN
		END;
	END Reset;

	PROCEDURE ShowArpCache*;
	BEGIN
		EnetArp.ShowArpCache(intf.ipv4AddrCache(EnetArp.ArpCache));
	END ShowArpCache;

	PROCEDURE ShowRecvCounter*;
	BEGIN
		Trace.StringLn("recvCounter=" & recvCounter);
	END ShowRecvCounter;

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

		runner.dstIpAddr := dstIpAddr;
		runner.dstPort := dstPort;

		runner.TriggerSetUdpDest;
	END SetUdpDest;

	PROCEDURE SendPackets*(context: Commands.Context);
	VAR n: Int;
	BEGIN
		ASSERT(context.arg.GetInteger(n,FALSE));
		runner.numPacketsToSend := n;
		runner.TriggerSend;
	END SendPackets;

	(*PROCEDURE FromMicro(us: EnetTiming.Time): EnetTiming.Time;
	BEGIN
		RETURN us * ENTIERH(0.5D0+Platform.CpuClockHz/2.0D6);
	END FromMicro;

	PROCEDURE FromMilli(ms: EnetTiming.Time): EnetTiming.Time;
	BEGIN
		RETURN ms * ENTIERH(0.5D0+Platform.CpuClockHz/2.0D3);
	END FromMilli;*)

	PROCEDURE InitMod;
	VAR
		res: Int;
		dev: EnetBase.LinkDevice;
		macAddr: EnetBase.MacAddr;
		ipAddr, gateway, subnetMask: EnetBase.IpAddr;
	BEGIN
		ASSERT(~EnetBase.ThreadSafe);

		NEW(runner);

		(* initialize the interface *)
		ASSERT(EmacPs7.GetDevice(0,2048,2048,8192,8192,dev,res));
		NEW(intf);
		Enet.InitInterface(intf,dev,res); ASSERT(res = 0);

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
		ASSERT(EnetUdp.SetRecvHandler(udpSocket,runner.UdpRecvHandler,res));
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
BootConfig.CpuNb = 2;
EnetBase.ThreadSafe = TRUE;
Enet.UseSpinLocks = TRUE;
EnetEmacPs7.AllowZeroPhyAddr = [TRUE,TRUE];
~

SystemTools.DoCommands
Release.Build -b -f=ARM.Release.Tool -o='--replacements=Replacements.tmp --noInitLocals --traceModule=Trace' --only="Kernel" ZynqMinos ~
Release.Build -b -f=ARM.Release.Tool -o='--replacements=Replacements.tmp --traceModule=Trace' --only="System Enet Shell" ZynqMinos ~
Compiler.Compile -b=ARM --traceModule=Trace --replacements=Replacements.tmp 
	Zynq.TestEnetST.Mod
~
~

Release.Build -l -f=ARM.Release.Tool --only="Kernel System Enet Shell" ZynqMinos ~

FSTools.CloseFiles Test.bin ~

FoxARMInstructionSet.Disassemble Test.bin -a=1A71E4H  ~ 
