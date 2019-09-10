MODULE WMPerfMonPluginNetStats; (** AUTHOR "staubesv"; PURPOSE "Performance Monitor network statistics plugin"; *)
(**
 * History:
 *
 *	26.02.2007	First release (staubesv)
 *)

IMPORT
	WMPerfMonPlugins, Modules, IP, TCP, UDP, DNS, ICMP, IPv4, KernelLog;

CONST
	ModuleName = "WMPerfMonPluginIP";

TYPE

	IPStatistics* = OBJECT(WMPerfMonPlugins.Plugin)

		PROCEDURE Init*(p : WMPerfMonPlugins.Parameter);
		VAR ds : WMPerfMonPlugins.DatasetDescriptor;
		BEGIN
			p.name := "IP"; p.description := "IP statistics"; p.modulename := ModuleName;
			p.autoMax := TRUE;
			p.minDigits := 9; p.fraction := 0; p.unit := "";

			NEW(ds, 20);
			ds[0].name := "NIPSentToSubnet";
			ds[1].name := "NIPSentToGateway";
			ds[2].name := "NIPSentBroadcast";
			ds[3].name := "NIPCantFragment";
			ds[4].name := "NIPRcvTotal";
			ds[5].name := "NIPTooSmall";
			ds[6].name := "NIPBadVersion";
			ds[7].name := "NIPOptions";
			ds[8].name := "NIPBadChecksum";
			ds[9].name := "NIPBadLength";
			ds[10].name := "NIPTrim";
			ds[11].name := "NIPBadHdrLen";
			ds[12].name := "NIPNotForUs";
			ds[13].name := "NIPCantReassemble";
			ds[14].name := "NIPSrcIsBroadcast";
			ds[15].name := "NIPDelivered";
			ds[16].name := "NIPNoReceiver";
			ds[17].name := "NIPForwarded";
			ds[18].name := "NIPSentLocalLoopback";
			ds[19].name := "NIPSentPointToPoint";
			p.datasetDescriptor := ds;
		END Init;

		PROCEDURE UpdateDataset*;
		BEGIN
			dataset[0] := IP.NIPSentToSubnet;
			dataset[1] := IP.NIPSentToGateway;
			dataset[2] := IP.NIPSentBroadcast;
			dataset[3] := IP.NIPCantFragment;
			dataset[4] := IP.NIPRcvTotal;
			dataset[5] := IP.NIPTooSmall;
			dataset[6] := IP.NIPBadVersion;
			dataset[7] := IP.NIPOptions;
			dataset[8] := IP.NIPBadChecksum;
			dataset[9] := IP.NIPBadLength;
			dataset[10] := IP.NIPTrim;
			dataset[11] := IP.NIPBadHdrLen;
			dataset[12] := IP.NIPNotForUs;
			dataset[13] := IP.NIPCantReassemble;
			dataset[14] := IP.NIPSrcIsBroadcast;
			dataset[15] := IP.NIPDelivered;
			dataset[16] := IP.NIPNoReceiver;
			dataset[17] := IP.NIPForwarded;
			dataset[18] := IP.NIPSentLocalLoopback;
			dataset[19] := IP.NIPSentPointToPoint;
		END UpdateDataset;

	END IPStatistics;

TYPE

	TCPStatistics* = OBJECT(WMPerfMonPlugins.Plugin)

		PROCEDURE Init*(p : WMPerfMonPlugins.Parameter);
		VAR ds : WMPerfMonPlugins.DatasetDescriptor;
		BEGIN
			p.name := "TCP"; p.description := "TCP statistics"; p.modulename := ModuleName;
			p.autoMax := TRUE;
			p.minDigits := 9; p.fraction := 0; p.unit := "";

			NEW(ds, 42);
			ds[0].name := "NTCPConnectAttempt";
			ds[1].name := "NTCPPersistTimer";
			ds[2].name := "NTCPFinWait2Timer";
			ds[3].name := "NTCPSendProbe";
			ds[4].name := "NTCPReXmtPack";
			ds[5].name := "NTCPReXmtByte";
			ds[6].name := "NTCPSendPack";
			ds[7].name := "NTCPSendByte";
			ds[8].name := "NTCPAcks";
			ds[9].name := "NTCPSendCtrl";
			ds[10].name := "NTCPSendUrg";
			ds[11].name := "NTCPSendWinUp";
			ds[12].name := "NTCPSegsTimed";
			ds[13].name := "NTCPSendTotal";
			ds[14].name := "NTCPKeepTimer";
			ds[15].name := "NTCPKeepProbe";
			ds[16].name := "NTCPReXmtTimer";
			ds[17].name := "NTCPRcvTotal";
			ds[18].name := "NTCPRcvOptions";
			ds[19].name := "NTCPCacheMiss";
			ds[20].name := "NTCPPredAck";
			ds[21].name := "NTCPAckPack";
			ds[22].name := "NTCPAckByte";
			ds[23].name := "NTCPPredData";
			ds[24].name := "NTCPRcvPackFast";
			ds[25].name := "NTCPRcvByteFast";
			ds[26].name := "NTCPConnects";
			ds[27].name := "NTCPRcvWinProbe";
			ds[28].name := "NTCPDrops";
			ds[29].name := "NTCPRcvWinUpd";
			ds[30].name := "NTCPRTTUpdated";
			ds[31].name := "NTCPDelAck";
			ds[32].name := "NTCPConnDrops";
			ds[33].name := "NTCPClosed";
			ds[34].name := "NTCPSplitBuffer";
			ds[35].name := "NTCPRcvPackSlow";
			ds[36].name := "NTCPRcvByteSlow";
			ds[37].name := "NTCPNewBufs";
			ds[38].name := "NTCPTimeWaitTimer";
			ds[39].name := "NTCPUnacceptable";
			ds[40].name := "NTCPAccepts";
			ds[41].name := "NTCPPersistDrop";
			p.datasetDescriptor := ds;
		END Init;

		PROCEDURE UpdateDataset*;
		BEGIN
			dataset[0] := TCP.NTCPConnectAttempt;
			dataset[1] := TCP.NTCPPersistTimer;
			dataset[2] := TCP.NTCPFinWait2Timer;
			dataset[3] := TCP.NTCPSendProbe;
			dataset[4] := TCP.NTCPReXmtPack;
			dataset[5] := TCP.NTCPReXmtByte;
			dataset[6] := TCP.NTCPSendPack;
			dataset[7] := TCP.NTCPSendByte;
			dataset[8] := TCP.NTCPAcks;
			dataset[9] := TCP.NTCPSendCtrl;
			dataset[10] := TCP.NTCPSendUrg;
			dataset[11] := TCP.NTCPSendWinUp;
			dataset[12] := TCP.NTCPSegsTimed;
			dataset[13] := TCP.NTCPSendTotal;
			dataset[14] := TCP.NTCPKeepTimer;
			dataset[15] := TCP.NTCPKeepProbe;
			dataset[16] := TCP.NTCPReXmtTimer;
			dataset[17] := TCP.NTCPRcvTotal;
			dataset[18] := TCP.NTCPRcvOptions;
			dataset[19] := TCP.NTCPCacheMiss;
			dataset[20] := TCP.NTCPPredAck;
			dataset[21] := TCP.NTCPAckPack;
			dataset[22] := TCP.NTCPAckByte;
			dataset[23] := TCP.NTCPPredData;
			dataset[24] := TCP.NTCPRcvPackFast;
			dataset[25] := TCP.NTCPRcvByteFast;
			dataset[26] := TCP.NTCPConnects;
			dataset[27] := TCP.NTCPRcvWinProbe;
			dataset[28] := TCP.NTCPDrops;
			dataset[29] := TCP.NTCPRcvWinUpd;
			dataset[30] := TCP.NTCPRTTUpdated;
			dataset[31] := TCP.NTCPDelAck;
			dataset[32] := TCP.NTCPConnDrops;
			dataset[33] := TCP.NTCPClosed;
			dataset[34] := TCP.NTCPSplitBuffer;
			dataset[35] := TCP.NTCPRcvPackSlow;
			dataset[36] := TCP.NTCPRcvByteSlow;
			dataset[37] := TCP.NTCPNewBufs;
			dataset[38] := TCP.NTCPTimeWaitTimer;
			dataset[39] := TCP.NTCPUnacceptable;
			dataset[40] := TCP.NTCPAccepts;
			dataset[41] := TCP.NTCPPersistDrop;
		END UpdateDataset;

	END TCPStatistics;

TYPE

	TCPErrors* = OBJECT(WMPerfMonPlugins.Plugin)

		PROCEDURE Init*(p : WMPerfMonPlugins.Parameter);
		VAR ds : WMPerfMonPlugins.DatasetDescriptor;
		BEGIN
			p.name := "TCPErrors"; p.description := "TCP error statistics"; p.modulename := ModuleName;
			p.autoMax := TRUE;
			p.minDigits := 9; p.fraction := 0; p.unit := "";

			NEW(ds, 36);
			ds[0].name := "NbrOfErrors";
			ds[1].name := "ConnectionRefused";
			ds[2].name := "ConnectionReset";
			ds[3].name := "WrongInterface";
			ds[4].name := "TimedOut";
			ds[5].name := "NotConnected";
			ds[6].name := "NoInterface";
			ds[7].name := "InterfaceClosed";
			ds[8].name := "BroadcastReceived";
			ds[9].name := "InvalidParameter";
			ds[10].name := "AllPortsInUse";
			ds[11].name := "AddressInUse";
			ds[12].name := "DuplicateSegment";
			ds[13].name := "DuplicatePartialSegment";
			ds[14].name := "DuplicateSegmentPAWS";
			ds[15].name := "DataBeyondWindow1";
			ds[16].name := "DataBeyondWindow2";
			ds[17].name := "DataBeyondWindow3";
			ds[18].name := "BadChecksum";
			ds[19].name := "DuplicateAck";
			ds[20].name := "OutOfRangeAck";
			ds[21].name := "TimeOutKeepAlive";
			ds[22].name := "TimeoutEstablished";
			ds[23].name := "SegmentTooBig";
			ds[24].name := "SegmentTooSmall";
			ds[25].name := "BadHeaderLength";
			ds[26].name := "ConnectionGone";
			ds[27].name := "NIYNewIncarnation";
			ds[28].name := "NIYOutOfBand";
			ds[29].name := "NIYMSS";
			ds[30].name := "ConnectionAborted";
			ds[31].name := "NotInitialized";
			ds[32].name := "DataDuplicatePrevComplete";
			ds[33].name := "DataDuplicatePrevPartial";
			ds[34].name := "DataDuplicateNextComplete";
			ds[35].name := "DataDuplicateNextPartial";
			p.datasetDescriptor := ds;

			IF LEN(TCP.NTCPError) # 36 THEN
				KernelLog.String("WMPerfMonPluginNetStats: Warning: Different number of TCP errors expected."); KernelLog.Ln;
			END;
		END Init;

		PROCEDURE UpdateDataset*;
		VAR i : SIGNED32;
		BEGIN
			FOR i := 0 TO LEN(TCP.NTCPError)-1 DO
				dataset[i] := TCP.NTCPError[i];
			END;
		END UpdateDataset;

	END TCPErrors;

TYPE

	UDPStatistics* = OBJECT(WMPerfMonPlugins.Plugin)

		PROCEDURE Init*(p : WMPerfMonPlugins.Parameter);
		VAR ds : WMPerfMonPlugins.DatasetDescriptor;
		BEGIN
			p.name := "UDP"; p.description := "UDP statistics"; p.modulename := ModuleName;
			p.autoMax := TRUE;
			p.minDigits := 9; p.fraction := 0; p.unit := "";

			NEW(ds, 9);
			ds[0].name := "NUDPRcvTotal";
			ds[1].name := "NUDPTooSmall";
			ds[2].name := "NUDPBadChecksum";
			ds[3].name := "NUDPRcvBroadcast";
			ds[4].name := "NUDPUnknownPort";
			ds[5].name := "NUDPQueued";
			ds[6].name := "NUDPQueueOverflow";
			ds[7].name := "NUDPTrim";
			ds[8].name := "NUDPBadHdrLen";
			p.datasetDescriptor := ds;
		END Init;

		PROCEDURE UpdateDataset*;
		BEGIN
			dataset[0] := UDP.NUDPRcvTotal;
			dataset[1] := UDP.NUDPTooSmall;
			dataset[2] := UDP.NUDPBadChecksum;
			dataset[3] := UDP.NUDPRcvBroadcast;
			dataset[4] := UDP.NUDPUnknownPort;
			dataset[5] := UDP.NUDPQueued;
			dataset[6] := UDP.NUDPQueueOverflow;
			dataset[7] := UDP.NUDPTrim;
			dataset[8] := UDP.NUDPBadHdrLen;
		END UpdateDataset;

	END UDPStatistics;

TYPE

	DNSStatistics* = OBJECT(WMPerfMonPlugins.Plugin)

		PROCEDURE Init*(p : WMPerfMonPlugins.Parameter);
		VAR ds : WMPerfMonPlugins.DatasetDescriptor;
		BEGIN
			p.name := "DNS"; p.description := "DNS statistics"; p.modulename := ModuleName;
			p.autoMax := TRUE;
			p.minDigits := 9; p.fraction := 0; p.unit := "";

			NEW(ds, 4);
			ds[0].name := "NDNSReceived";
			ds[1].name := "NDNSSent";
			ds[2].name := "NDNSMismatchID";
			ds[3].name := "NDNSError";
			p.datasetDescriptor := ds;
		END Init;

		PROCEDURE UpdateDataset*;
		BEGIN
			dataset[0] := DNS.NDNSReceived;
			dataset[1] := DNS.NDNSSent;
			dataset[2] := DNS.NDNSMismatchID;
			dataset[3] := DNS.NDNSError;
		END UpdateDataset;

	END DNSStatistics;

TYPE

	ICMPStatistics* = OBJECT(WMPerfMonPlugins.Plugin)

		PROCEDURE Init*(p : WMPerfMonPlugins.Parameter);
		VAR ds : WMPerfMonPlugins.DatasetDescriptor;
		BEGIN
			p.name := "ICMP"; p.description := "ICMP statistics"; p.modulename := ModuleName;
			p.autoMax := TRUE;
			p.minDigits := 9; p.fraction := 0; p.unit := "";

			NEW(ds, 7);
			ds[0].name := "NICMPRcvTotal";
			ds[1].name := "NICMPTooSmall";
			ds[2].name := "NICMPBadChecksum";
			ds[3].name := "NICMPNoReceiver";
			ds[4].name := "NICMPDelivered";
			ds[5].name := "NICMPEchoRequest";
			ds[6].name := "NICMPSend";
			p.datasetDescriptor := ds;
		END Init;

		PROCEDURE UpdateDataset*;
		BEGIN
			dataset[0] := ICMP.NICMPRcvTotal;
			dataset[1] := ICMP.NICMPTooSmall;
			dataset[2] := ICMP.NICMPBadChecksum;
			dataset[3] := ICMP.NICMPNoReceiver;
			dataset[4] := ICMP.NICMPDelivered;
			dataset[5] := ICMP.NICMPEchoRequest;
			dataset[6] := ICMP.NICMPSend;
		END UpdateDataset;

	END ICMPStatistics;

TYPE

	ARPStatistics* = OBJECT(WMPerfMonPlugins.Plugin)

		PROCEDURE Init*(p : WMPerfMonPlugins.Parameter);
		VAR ds : WMPerfMonPlugins.DatasetDescriptor;
		BEGIN
			p.name := "IPv4"; p.description := "IPv4 ARP statistics"; p.modulename := ModuleName;
			p.autoMax := TRUE;
			p.minDigits := 9; p.fraction := 0; p.unit := "";

			NEW(ds, 9);
			ds[0].name := "NARPPut";
			ds[1].name := "NARPRcvTotal";
			ds[2].name := "NARPRcvTooSmall";
			ds[3].name := "NARPRcvIgnored";
			ds[4].name := "NARPRcvDuplicate";
			ds[5].name := "NARPBadAddr";
			ds[6].name := "NARPRequest";
			ds[7].name := "NARPReply";
			ds[8].name := "NARPSkipped";
			p.datasetDescriptor := ds;
		END Init;

		PROCEDURE UpdateDataset*;
		BEGIN
			dataset[0] := IPv4.NARPPut;
			dataset[1] := IPv4.NARPRcvTotal;
			dataset[2] := IPv4.NARPRcvTooSmall;
			dataset[3] := IPv4.NARPRcvIgnored;
			dataset[4] := IPv4.NARPRcvDuplicate;
			dataset[5] := IPv4.NARPBadAddr;
			dataset[6] := IPv4.NARPRequest;
			dataset[7] := IPv4.NARPReply;
			dataset[8] := IPv4.NARPSkipped;
		END UpdateDataset;

	END ARPStatistics;

PROCEDURE InitPlugins;
VAR
	ip : IPStatistics;
	tcp : TCPStatistics;
	tcpErrors : TCPErrors;
	udp : UDPStatistics;
	dns : DNSStatistics;
	icmp : ICMPStatistics;
	arp : ARPStatistics;
	par : WMPerfMonPlugins.Parameter;
BEGIN
	NEW(par); NEW(ip, par);
	NEW(par); NEW(tcp, par);
	NEW(par); NEW(tcpErrors, par);
	NEW(par); NEW(udp, par);
	NEW(par); NEW(dns, par);
	NEW(par); NEW(icmp, par);
	NEW(par); NEW(arp, par);
END InitPlugins;

PROCEDURE Install*; (** ~ *)
END Install;

PROCEDURE Cleanup;
BEGIN
	WMPerfMonPlugins.updater.RemoveByModuleName(ModuleName);
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
	InitPlugins;
END WMPerfMonPluginNetStats.

WMPerfMonPluginNetStats.Install ~  System.Free WMPerfMonPluginNetStats ~
