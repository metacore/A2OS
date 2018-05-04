HEADER
	VERSION "1.0"
END

PACKAGE EnetMinos ARCHIVE "EnetMinos.zip" SOURCE "EnetMinosSrc.zip" DESCRIPTION "MINOS runtime needed by Enet"
	MINOS:/UncachedHeaps.Mos
	MINOS:/StreamReaders.Mos
	MINOS:/StreamWriters.Mos
END

PACKAGE Enet ARCHIVE "Enet.zip" SOURCE "EnetSrc.zip" DESCRIPTION "Enet network stack for Minos"
	ENET:/Minos.EnetEnvironment.Mod
	ENET:/EnetTiming.Mod
	ENET:/EnetUtils.Mod
	ENET:/EnetTrace.Mod
	ENET:/EnetBase.Mod
	ENET:/EnetInterfaces.Mod
	ENET:/EnetArp.Mod
	ENET:/EnetIcmp.Mod
	ENET:/Minos.EnetStreams.Mod
	ENET:/EnetUdp.Mod
	ENET:/EnetUdpChannels.Mod
	ENET:/EnetTftp.Mod
	ENET:/Enet.Mod
	ENET:/EnetPhy.Mod
	ENET:/Zynq.EnetEmacPs7.Mod
END