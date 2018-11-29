HEADER
	VERSION "1.0"
END

PACKAGE EnetMinos ARCHIVE "EnetMinos.zip" SOURCE "EnetMinosSrc.zip" DESCRIPTION "MINOS runtime needed by Enet"
	ARM/Minos/Trace.Mos
	ARM/Minos/UncachedHeaps.Mos
	ARM/Minos/StreamReaders.Mos
	ARM/Minos/StreamWriters.Mos
END

PACKAGE Enet ARCHIVE "Enet.zip" SOURCE "EnetSrc.zip" DESCRIPTION "Enet network stack for Minos"
	ARM/Enet/Minos.EnetEnvironment.Mod
	ARM/Enet/EnetTiming.Mod
	ARM/Enet/EnetUtils.Mod
	ARM/Enet/EnetTrace.Mod
	ARM/Enet/EnetBase.Mod
	ARM/Enet/EnetInterfaces.Mod
	ARM/Enet/EnetArp.Mod
	ARM/Enet/EnetIcmp.Mod
	ARM/Enet/Minos.EnetStreams.Mod
	ARM/Enet/EnetUdp.Mod
	ARM/Enet/EnetUdpChannels.Mod
	ARM/Enet/EnetTftp.Mod
	ARM/Enet/Enet.Mod
	ARM/Enet/EnetPhy.Mod
	ARM/Enet/Zynq.EnetEmacPs7.Mod
END